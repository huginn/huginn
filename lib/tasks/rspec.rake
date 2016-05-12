if defined? RSpec
  namespace :spec do
    desc 'Run all specs in spec directory (exluding feature specs)'
    RSpec::Core::RakeTask.new(:nofeatures) do |task|
      ENV['RSPEC_TASK'] = 'spec:nofeatures'
      task.exclude_pattern = "spec/features/**/*_spec.rb"
    end
  end
end
