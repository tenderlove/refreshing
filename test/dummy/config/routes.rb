Rails.application.routes.draw do
  mount LiveCoding::Engine => "/live_coding"
end
