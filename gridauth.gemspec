require_relative "lib/gridauth/version"

Gem::Specification.new do |spec|
  spec.name        = "gridauth"
  spec.version     = Gridauth::VERSION
  spec.authors     = [ "jcallahan" ]
  spec.email       = [ "jcallahan@acm.org" ]
  spec.summary     = "Grid card two-factor authentication for Rails 8 built-in authentication."
  spec.description = "Adds a grid card (a printed table of random characters) as a second factor to Rails 8+ " \
                     "apps using `bin/rails generate authentication`: per-user cards, card rotation, and a " \
                     "challenge step after the password sign-in."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md", "CHANGELOG.md"]
  end

  spec.add_dependency "rails", ">= 8.0"
end
