module Refreshing
  class RefreshController < ApplicationController
    include ActionController::Live

    def index
      response.headers['Content-Type'] = 'text/event-stream'
      response.headers['Last-Modified'] = Time.now.httpdate
      sse = SSE.new(response.stream, event: "status")
      Refreshing::MSGS.clear
      while msg = Refreshing::MSGS.shift
        sse.write(JSON.dump(msg))
        if msg["type"] == "refresh"
          response.stream.close
          return
        end
      end
    end
  end
end
