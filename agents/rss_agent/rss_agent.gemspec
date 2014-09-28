# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "rss_agent"
  spec.version       = '0.1'
  spec.authors       = ["Andrew Cantino"]
  spec.email         = ["https://github.com/cantino/huginn"]
  spec.summary       = %q{The default Huginn RSSAgent for consuming RSS and Atom feeds.}
  spec.homepage      = "https://github.com/cantino/huginn"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  
  spec.add_runtime_dependency "huginn_agent"
  spec.add_runtime_dependency "feed-normalizer", "~> 1.5.2"
end
