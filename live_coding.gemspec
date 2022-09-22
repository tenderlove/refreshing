require_relative "lib/live_coding/version"

Gem::Specification.new do |spec|
  spec.name        = "live_coding"
  spec.version     = LiveCoding::VERSION
  spec.authors     = ["Aaron Patterson"]
  spec.email       = ["tenderlove@ruby-lang.org"]
  spec.homepage    = "https://example.com"
  spec.summary     = "lmao no"
  spec.description = "lmao stop"
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://example.com"
  spec.metadata["changelog_uri"] = "https://example.com"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 7.0.4"
end
