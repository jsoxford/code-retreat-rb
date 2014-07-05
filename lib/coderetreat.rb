# encoding: UTF-8
require 'socket'
require 'json'
require 'digest'
require 'rspec'
require 'active_support/core_ext/hash/indifferent_access'

class CodeRetreatRunner
    def run(filename)
        STDOUT.puts "Watching " + filename

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

            symbols = {passed: '✓', pending: '.', failed: '✖'}
            STDOUT.puts data[:examples].map{ |example| ' ' + symbols[example[:status].to_sym] }.join('')

            data[:examples].select{ |example| example[:status] == 'failed' }.map do |example|
                STDOUT.puts "fail: #{example[:full_description]} -- error: #{example[:exception][:message]}"
            end

            send('consumeTestResults', {
                testsRun: data[:summary][:example_count],
                testsFailed: data[:summary][:failure_count],
                testsIgnored: data[:summary][:pending_count]
            })

        rescue Exception => e
            STDOUT.puts "Failed to load your code, do you have errors in your Ruby? Exception: [#{e}]"
        end
    end

    def connect
        @client ||= TCPSocket.open '127.0.0.1', 8787
        @data = ''
    end

    def send(action, payload)
        connect
        @client.write JSON.generate({ action: action, payload: payload })
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
        case data[:action]
        when 'tickBoard'
            [{
                generation: data[:payload][:generation],
                result: data[:payload][:result]
            }, {
                generation: data[:payload][:generation] + 1,
                result: data[:payload][:result]
            }];
        when 'tickCell'
            [{
                generation: data[:payload][:generation],
                result: data[:payload][:result]
            }, {
                generation: data[:payload][:generation] + 1,
                result: data[:payload][:result]
            }];
        else
        end
    end

    def receive
        connect
        data = @client.recv(8)
        unless data.nil?
            @data += data
            begin
                respond(JSON.parse(@data).with_indifferent_access)
                @data = ''
            rescue JSON::ParserError => e
            end
        end
    end
end
