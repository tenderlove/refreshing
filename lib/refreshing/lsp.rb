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

    class Workspace
      def initialize root
        @root = root
      end
    end

    class Events
      EVENT_MAP = Ractor.make_shareable({
        "initialize"              => :on_initialize,
        "initialized"             => :on_initialized,
        "textDocument/didOpen"    => :did_open,
        "textDocument/didChange"  => :did_change,
        "textDocument/didClose"   => :did_close,
        "textDocument/didSave"    => :did_save,
        "textDocument/hover"      => :on_hover,
        "textDocument/definition" => :on_definition,
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

      def on_definition request, writer
        $stderr.puts request.inspect
        # {:id=>2, :jsonrpc=>"2.0", :method=>"textDocument/definition", :params=>{:textDocument=>{:uri=>"file:///Users/aaron/git/blogsite/app/views/posts/index.html.erb"}, :position=>{:character=>24, :line=>4}}}
        uri = request.dig(:params, :textDocument, :uri)
        text = @files[uri].text
        line = text.lines[request.dig(:params, :position, :line)]
        idx  = request.dig(:params, :position, :character)
        token = line[/^.{#{idx}}\w+/][/\w+$/]
        $stderr.puts token

        result = {}
        if token && token =~ /^([a-z_]+)(_path|_url)$/
          # check if it's a route helper
          if Rails.application.routes.named_routes.key?($1)
            route = Rails.application.routes.named_routes.get($1)
            file, line = route.source_location.split(':')
            file = File.join(@root, file)
            char = File.readlines(file)[line.to_i].index(/[^\s]/)
            uri = "file://" + file
            result[:uri] = uri
            result[:range] = {
              start: { line: line.to_i - 1, character: char }
            }
            writer.write(id: request[:id], result: result)
          else
          end
        end
      end

      def on_hover request, writer
        $stderr.puts request.inspect
        uri = request.dig(:params, :textDocument, :uri)
        text = @files[uri].text
        line = text.lines[request.dig(:params, :position, :line)]
        $stderr.puts line
        idx  = request.dig(:params, :position, :character)
        token = line[/^.{#{idx}}\w+/][/\w+$/]
        $stderr.puts token
        value = "Omg!!"

        if token && token =~ /^([a-z_]+)(_path|_url)$/
          # check if it's a route helper
          if Rails.application.routes.named_routes.key?($1)
            route = Rails.application.routes.named_routes.get($1)
            controller = route.requirements[:controller]
            action = route.requirements[:action]
            value = "URI Pattern:       #{route.path.spec.to_s}\nController#Action: #{controller}##{action}"
          else
            value = "Something else"
          end
        else
          if token && token =~ /^[A-Z]/
            const = Object.const_get(token)
            value = "# #{const.name}\n"
            if const < ActiveRecord::Base
              name_header = "Column Name"
              type_header = "Column Type"
              info = [[name_header, type_header]] + const.columns.map { |column|
                [column.name.to_s, column.type.to_s]
              }
              max_name_len = info.map(&:first).sort_by(&:length).last.length
              max_type_len = info.map(&:last).sort_by(&:length).last.length

              name_header, type_header = *info.shift
              value << ("| " + name_header.ljust(max_name_len))
              value << (" | " + type_header.ljust(max_type_len) + " |\n")
              value << ("| " + ("-" * max_name_len))
              value << (" | " + ("-" * max_type_len) + " |\n")
              info.each do |name, type|
                value << ("| " + name.ljust(max_name_len))
                value << (" | " + type.ljust(max_type_len) + " |\n")
              end
            end
          end
        end
        result = {
          contents: {
            kind: "markdown",
            value: value
          }
        }
        writer.write(id: request[:id], result: result)
      end

      Opened = Struct.new(:uri, :text, :version)

      class Changed < Struct.new(:parent, :content_changes, :version)
        def text
          content_changes.first[:text]
        end
      end

      def did_open request, writer
        doc = request.dig(:params, :textDocument)

        # store the original version
        @files[doc[:uri]] = Opened.new(doc[:uri], doc[:text], doc[:version])
      end

      def did_change request, writer
        doc = request.dig(:params, :textDocument)

        wrapper = @files[doc[:uri]]
        version = doc[:version]

        wrapper = Changed.new(wrapper, request.dig(:params, :contentChanges), version)
        @files[doc[:uri]] = wrapper
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
            },
            "diagnosticProvider" => {
              "interFileDependencies" => true,
            },
            "definitionProvider" => true,
            "hoverProvider" => true,
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
