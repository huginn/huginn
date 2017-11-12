#!/usr/bin/env ruby

# This file loads spring without using Bundler, in order to be fast.
# It gets overwritten when you run the `spring binstub` command.

unless defined?(Spring)
  require 'rubygems'
  require 'bundler'

  lockfile = Bundler::LockfileParser.new(Bundler.default_lockfile.read)
  spring = lockfile.specs.detect { |spec| spec.name == "spring" }
  if spring
    Gem.use_paths Gem.dir, Bundler.bundle_path.to_s, *Gem.path
    gem 'spring', spring.version
    require 'spring/binstub'
  end
end
