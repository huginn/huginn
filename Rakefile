#!/usr/bin/env rake
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)

Huginn::Application.load_tasks

task("spec").clear
RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = ['spec/**/*_spec.rb', 'agents/**/spec/**/*_spec.rb']
end

task :default => :spec
