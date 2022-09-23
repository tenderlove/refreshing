module Refreshing
  class Middleware
    def initialize app
      @app = app
    end

    def call env
      status, headers, body = @app.call env
      if status == 200 && headers["Content-Type"] =~ /text\/html/
        Refreshing::LSP::ERROR_QUEUE << [:clear, "cool"]
      end
      [status, headers, body]
    end
  end
end
