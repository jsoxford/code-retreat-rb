# encoding: UTF-8
require 'socket'
require 'json'
require 'digest'
require 'active_support/core_ext/hash/indifferent_access'
require 'net/http'
require 'rspec'

class CodeRetreatRunner

  def self.config(url)
    JSON.parse(Net::HTTP.get(URI(url)))['endpoint'].with_indifferent_access
  end

  # Runs the runner
  def run(filename, config)
    STDOUT.puts "Watching #{filename}"

    unless File.exists?(filename)
      return STDOUT.puts 'Something went pretty badly wrong. Does that file exist?'
    end

    STDOUT.puts "Connecting to #{config[:host]}:#{config[:port]}"
    connect(config)

    # Receive data and check the test file indefinitely
    loop do
      test(filename) if changed(filename)
      receive
    end
  end

  # Runs the tests in the test file
  def test(filename)
    begin
      RSpec.reset
      config = RSpec.configuration
      config.color = true

      json_formatter = RSpec::Core::Formatters::JsonFormatter.new(config.output_stream)
      reporter =  RSpec::Core::Reporter.new(config)
      reporter.register_listener(json_formatter, :message, :dump_summary, :stop)
      config.instance_variable_set(:@reporter, reporter)

      RSpec::Core::Runner.run([filename])
      data = json_formatter.output_hash

      setInterrupt

      symbols = {passed: '✓', pending: '.', failed: '✖'}
      STDOUT.puts data[:examples].map{ |example| ' ' + symbols[example[:status].to_sym] }.join('')

      data[:examples].select{ |example| example[:status] == 'failed' }.map do |example|
        STDOUT.puts "fail: #{example[:full_description]} -- error: #{example[:exception][:message]}"
      end

      send({
        action: 'consumeTestResults',
        payload: {
          testsRun: data[:summary][:example_count],
          testsFailed: data[:summary][:failure_count],
          testsIgnored: data[:summary][:pending_count]
        }
      })

    rescue Exception => e
      STDOUT.puts "Failed to load your code, do you have errors in your Ruby? Exception: [#{e}]"
    end
  end

  # Connects the TCP socket
  def connect(config)
    @client = TCPSocket.open config[:host], config[:port]
    setInterrupt
  end

  # Disconnects the TCP socket
  def disconnect
    @client.close if @client
  end

  # Disable rspec interrupt, and disconnect our socket on close
  def setInterrupt
    Signal.trap('INT') do
      disconnect
      Kernel.exit(0)
    end
  end

  # Sends JSON through the TCP socket
  def send(data)
    @client.write JSON.generate(data)
  end

  # Checks if the test file has changed (no more than once a second)
  def changed(filename)
    changed = false
    now = Time.now.to_f

    @timestamp ||= now
    @fileHash ||= ''

    if now - @timestamp > 1
      File.open(filename, "r") do |file|
        fileHash = Digest::SHA1.hexdigest(File.read(filename))
        changed = fileHash != @fileHash
        @fileHash = fileHash
      end

      @timestamp = now
    end

    changed
  end

  # Responds to a request
  def respond(data)
    payload = data[:payload]
    success = false
    message = nil

    begin
      case data[:action]
      when 'tickBoard'
        # CodeRetreat.tickBoard(payload[:result])
        payload = {}
        success = false
      when 'tickCell'
        payload[:generation]++
        payload[:lives] = CodeRetreat.tickCell(payload[:result])
        payload[:from] = payload[:result]
        payload.delete(:result)
        success = true
      else
        message = "I don't understand the action requested: #{data[:action]}"
      end
    rescue Exception => e
      message = "Requested action had an error: #{data[:action]}"
    end

    send({ respondingTo: data[:action], success: success, message: message, payload: payload })
  end

  # Recieve data from the TCP socket and buffers into JSON objects
  def receive
    @buffer ||= ''
    data = @client.recv(128)
    unless data.nil?
      @buffer += data

      jsons = @buffer.split("\n")
      jsons.each do |json|
        respond(JSON.parse(json).with_indifferent_access) rescue nil
      end

      @buffer = jsons.last unless @buffer.match(/\n$/)
    end
  end
end
