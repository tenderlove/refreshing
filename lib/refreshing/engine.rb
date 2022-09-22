module Refreshing
  class Engine < ::Rails::Engine
    isolate_namespace Refreshing

    initializer "refreshing.importmap", before: "importmap" do |app|
      app.config.importmap.paths << Engine.root.join("config/importmap.rb")
    end

    initializer "refreshing.assets.precompile" do |app|
      app.config.assets.precompile += %w( refreshing.js )
    end
  end
end
