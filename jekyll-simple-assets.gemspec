# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "jekyll-simple-assets/version"

Gem::Specification.new do |spec|
	spec.name          = "jekyll-simple-assets"
	spec.version       = Jekyll::SimpleAssets::VERSION
	spec.authors       = ["Sophie Askew"]
	spec.email         = ["sophie@ofthewi.red"]
	spec.summary       = "Some simple asset utils for jekyll"
	spec.homepage      = "https://github.com/syldexiahime/jekyll-simple-assets"
	spec.license       = "GPL-3.0+"
	
	spec.files         = `git ls-files -z`.split("\x0")
	spec.require_paths = ["lib"]
	
	spec.required_ruby_version = ">= 2.3.0"
	
	spec.add_runtime_dependency "jekyll"
	spec.add_runtime_dependency "css_parser"
	spec.add_runtime_dependency "uglifier"
	
	spec.add_development_dependency "bundler"
end
