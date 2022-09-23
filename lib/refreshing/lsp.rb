# frozen_string_literal: true

module Refreshing
  module LSP
    ERROR_QUEUE = Queue.new

    class Reader
      def initialize io
        @io = io.binmode
      end

      def read
        buffer = @io.gets("\r\n\r\n")
        content_length = buffer.match(/Content-Length: (\d+)/i)[1].to_i
        message = @io.read(content_length)
        JSON.parse message, symbolize_names: true
      end
    end

    class Writer
      def initialize io
        @io = io.binmode
      end

      def write response
        str = JSON.dump(response.merge(jsonrpc: "2.0"))

        @io.write "Content-Length: #{str.bytesize}\r\n"
        @io.write "\r\n"
        @io.write str
        @io.flush
      end
    end

    class Events
      EVENT_MAP = Ractor.make_shareable({
        "initialize"             => :on_initialize,
        "initialized"            => :on_initialized,
        "textDocument/didOpen"   => :did_open,
        "textDocument/didChange" => :did_change,
        "textDocument/didClose"  => :did_close,
        "textDocument/didSave"   => :did_save,
      })

      attr_reader :files

      def initialize
        @files = {}
        @test_thread = nil
      end

      def handle event, request, writer
        $stderr.puts "Got event: #{event} #{request}"

        method = EVENT_MAP[event]
        if method
          send method, request, writer
        else
          $stderr.puts "No mapping for #{event}"
        end
      end

      private

      def did_open request, writer
        doc = request.dig(:params, :textDocument)

        # store the original version
        @files[doc[:uri]] = doc[:version]
      end

      def did_change request, writer
        doc = request.dig(:params, :textDocument)

        # bump the version if we're out of date
        @files[doc[:uri]] = doc[:version] if @files[doc[:uri]] < doc[:version]
      end

      def did_save request, writer
        doc = request.dig(:params, :textDocument)
        MSGS.push({ "type" => "refresh", "when" => Time.now }, false)
      end

      def did_close request, writer
      end

      def on_initialized request, writer
      end

      def on_initialize request, writer
        result = {
          "capabilities" => {
            "textDocumentSync" => {
              "openClose" => true,"change" => 1,"save" => true
            }
          }
        }

        @root = request.dig(:params, :rootUri).delete_prefix("file://")

        writer.write(id: request[:id], result: result)
      end
    end

    class Reader
      def initialize io = $stdin
        @io = io.binmode
      end

      def read
        buffer = @io.gets("\r\n\r\n")
        content_length = buffer.match(/Content-Length: (\d+)/i)[1].to_i
        message = @io.read(content_length)
        JSON.parse message, symbolize_names: true
      end
    end

    class Writer
      def handle event, request, writer
        $stderr.puts "Got event: #{event} #{request}"

        method = EVENT_MAP[event]
        if method
          send method, request, writer
        else
          $stderr.puts "No mapping for #{event}"
        end
      end
    end

    def self.run_lsp wr, rd
      writer = Writer.new wr
      reader = Reader.new rd
      subscriber = Events.new

      ERROR_QUEUE.clear

      Thread.new do
        while item = ERROR_QUEUE.pop
          type, val = *item
          if type == :clear
            subscriber.files.each do |file, version|
              val = { uri: file, version: version, diagnostics: [] }
              writer.write(method: "textDocument/publishDiagnostics", params: val)
            end
          else
            val[:version] = subscriber.files[val[:uri]]
            $stderr.puts "sending: " + val.inspect
            writer.write(method: "textDocument/publishDiagnostics", params: val)
          end
        end
        puts "quitting"
      end

      loop do
        request = reader.read
        subscriber.handle request[:method], request, writer
      end
    end
  end
end
