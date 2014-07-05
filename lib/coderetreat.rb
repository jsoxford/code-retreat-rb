# encoding: UTF-8
require 'socket'
require 'json'
require 'digest'
require 'rspec'
require 'active_support/core_ext/hash/indifferent_access'

class CodeRetreatRunner
    def run(filename)
        STDOUT.puts 'Watching ' + filename

        unless File.exists?(filename)
            return STDOUT.puts 'Something went pretty badly wrong. Does that file exist?'
        end

        connect('127.0.0.1', 8787)

        loop do
            test(filename) if changed(filename)
            receive
        end
    end

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

            # Disable rspec interrupt, and disconnect our socket on close
            Signal.trap('INT') do
                disconnect
                Kernel.exit(0)
            end

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

    def connect(address, port)
        @client = TCPSocket.open address, port
    end

    def disconnect
        @client.close if @client
    end

    def send(data)
        @client.write JSON.generate(data)
    end

    def changed(filename)
        changed = false
        now = Time.now.to_f

        @timestamp ||= now
        @fileHash ||= ''

        if now - @timestamp > 1
            File.open(File.expand_path(filename, File.dirname(__FILE__) + '/..'), "r") do |file|
                fileHash = Digest::SHA1.hexdigest(File.read(filename))
                changed = fileHash != @fileHash
                @fileHash = fileHash
            end

            @timestamp = now
        end

        changed
    end

    def respond(data)
        payload = data[:payload]
        success = false
        message = nil

        begin
            case data[:action]
            when 'tickBoard'
                CodeRetreat.tickBoard(payload[:result])
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
