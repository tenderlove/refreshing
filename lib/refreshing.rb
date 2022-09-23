require "refreshing/version"
require "refreshing/engine"
require "refreshing/lsp"
require "drb"
require "action_view/template/error"
require "action_dispatch/middleware/debug_view"

view_path = File.dirname(File.expand_path(__FILE__))
view_path = File.expand_path(File.join(view_path, "..", "app", "views"))

ActionDispatch::DebugView::RESCUES_TEMPLATE_PATHS << view_path

require "error_highlight"

class ActionDispatch::DebugView
  def send_exception ex
    resp = {
      uri: "file://" + ex.file_name,
      diagnostics: [
        "range" => {
          "start" => { "character" => 0, "line" => (ex.line_number.to_i - 1) },
          "end" => { "character" => 65536, "line" => (ex.line_number.to_i - 1) },
        },
        "severity" => 1,
        "message" => ex.message
      ]
    }
    Refreshing::LSP::ERROR_QUEUE << [:error, resp]
  end
end

module Refreshing
  EX_TEMPLATES = ActionDispatch::ExceptionWrapper.rescue_templates

  js = File.dirname(File.expand_path(__FILE__))
  js = File.expand_path(File.join(js, "..", "app", "assets", "javascript", "refreshing.js"))
  JS = File.binread(js)
  ActionDispatch::ExceptionWrapper.rescue_templates = Hash.new("refresher")

  MSGS = SizedQueue.new(15)

  heartbeat = Thread.new do
    loop do
      #MSGS.push({ "type" => "refresh", "when" => Time.now })
      MSGS.push({ "type" => "heartbeat", "when" => Time.now })
      sleep 5
    end
  end
end
