module LiveCoding
  class RefreshController < ApplicationController
    include ActionController::Live

    def index
      response.headers['Content-Type'] = 'text/event-stream'
      response.headers['Last-Modified'] = Time.now.httpdate
      sse = SSE.new(response.stream, event: "status")
      10.times do
        sse.write('hello world')
        sleep 1
      end
    end
  end
end
