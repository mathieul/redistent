# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'redistent/version'

Gem::Specification.new do |spec|
  spec.name          = "redistent"
  spec.version       = Redistent::VERSION
  spec.authors       = ["Mathieu Lajugie"]
  spec.email         = ["mathieul@gmail.com"]
  spec.description   = %q{Light persistent layer for Ruby objects using Redis and a centralized persister object.}
  spec.summary       = spec.description
  spec.homepage      = "https://github.com/mathieul/redistent"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "redis", "~> 3.0.3"
  spec.add_dependency "nest",  "~> 1.1.2"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "virtus",  "~> 0.5.4"
  spec.add_development_dependency "pry-nav"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rb-fsevent"
  spec.add_development_dependency "guard-rspec"
  spec.add_development_dependency "coveralls"
end
