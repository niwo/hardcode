# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'hardcode/version'

Gem::Specification.new do |spec|
  spec.name          = "hardcode"
  spec.version       = Hardcode::VERSION
  spec.authors       = ["niwo"]
  spec.email         = ["nik.wolfgramm@gmail.com"]
  spec.summary       = %q{stack-encode on steroids (using a rabbitmq worker queue)}
  spec.description   = %q{stack-encode on steroids (using a rabbitmq worker queue)}
  spec.homepage      = "https://github.com/swisstxt/hardcode"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "thor"
  spec.add_dependency "sneakers"
  spec.add_dependency "bunny", ">= 0.9.1"
  spec.add_dependency "json"
  spec.add_dependency "stack-encode"

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
end
