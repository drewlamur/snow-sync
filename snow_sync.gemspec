require File.expand_path("../lib/snow_sync/version.rb", __FILE__)
require 'date'

Gem::Specification.new do |spec|

  spec.name    = "snow_sync"
  spec.version = SnowSync::VERSION
  spec.date    = Date.today.to_s

  spec.summary = "SnowSync is a file sync utility tool and API which provides a bridge for off platform ServiceNow development using an IDE or text editor locally."
  spec.description = "SnowSync syncronizes configured fields (scripts) for a ServiceNow instance locally, then watches for file changes and syncs back changes to the corresponding record."

  spec.authors  = ["Andy Wallace"]
  spec.email    = "sailingthetechseas@gmail.com"
  spec.homepage = "https://rubygems.org/gems/snow_sync"
  spec.license  = "MIT"

  spec.add_development_dependency "bundler", "~> 2.3.3"
  spec.add_development_dependency "facets", "~> 3.1.0"
  spec.add_development_dependency "guard", "~> 2.14.0"
  spec.add_development_dependency "guard-yield", "~> 0.1.0"
  spec.add_development_dependency "json", "~> 2.6.1"
  spec.add_development_dependency "libnotify", "~> 0.9.2"
  spec.add_development_dependency "rake", "~> 13.0.6"
  spec.add_development_dependency "rest-client", "~> 2.0.0"
  spec.add_development_dependency "rspec", "~> 3.10.0"
  spec.add_development_dependency "rspec-core", "~> 3.10.1"
  spec.add_development_dependency "terminal-notifier-guard", "~> 1.7"
  spec.add_development_dependency "thor", "0.19.1"

  # ensure gem is built out of versioned files
  spec.files = Dir['Rakefile', '{bin,lib,spec}/**/*', 'README*', 'LICENSE*'] & `git ls-files -z`.split("\0")

end
