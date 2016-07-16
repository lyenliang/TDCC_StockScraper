# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tdcc/version'

Gem::Specification.new do |spec|
  spec.name        = 'tdcc'
  spec.version     = '0.1.0'
  spec.date        = '2016-07-13'
  spec.summary     = "Taiwan Desitory & Clearing Corporation(TDCC)"
  spec.description = "A gem for fetching data from Taiwan Desitory & Clearing Corporation(TDCC)"
  spec.authors     = ["Lee Yen-Liang"]
  spec.email       = 'lyenliang@gmail.com'
  spec.files       = ["lib/tdcc.rb"]
  spec.license     = 'MIT'
  spec.homepage    = 'https://github.com/lyenliang/TDCC_StockScraper'
  spec.add_dependency "nokogiri"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
end
