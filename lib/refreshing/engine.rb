require "refreshing/middleware"

module Refreshing
  class Engine < ::Rails::Engine
    isolate_namespace Refreshing

    initializer "refreshing.importmap", before: "importmap" do |app|
      app.config.importmap.paths << Engine.root.join("config/importmap.rb")
    end

    initializer "refreshing.assets.precompile" do |app|
      app.config.assets.precompile += %w( refreshing.js )
    end

    initializer "refreshing.lsp" do |app|
      Thread.new do
        server = TCPServer.new 2000

        loop do
          client = server.accept
          $stderr.puts "HIIII"
          begin
            Refreshing::LSP.run_lsp client, client
          rescue Exception => e
            $stderr.puts e.inspect
            $stderr.puts e.backtrace.inspect
            $stderr.puts "exited yikes"
            Refreshing::LSP::ERROR_QUEUE << nil
          end
        end
      end
    end

    initializer "refreshing.add_middleware" do |app|
      app.middleware.insert_before ActionDispatch::DebugExceptions, Refreshing::Middleware
    end
  end
end
