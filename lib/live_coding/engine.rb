module LiveCoding
  class Engine < ::Rails::Engine
    isolate_namespace LiveCoding

    initializer "live_coding.importmap", before: "importmap" do |app|
      app.config.importmap.paths << Engine.root.join("config/importmap.rb")
    end

    initializer "love_coding.assets.precompile" do |app|
      app.config.assets.precompile += %w( refreshing.js )
    end
  end
end
