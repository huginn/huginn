namespace :javascript_agent do
  desc "Bundle the whatwg-url polyfill used by JavaScriptAgent.fetch"
  task :build_url_polyfill do
    sh "npm run build"
  end
end

%w[assets:precompile spec].each do |name|
  Rake::Task[name].enhance(["javascript_agent:build_url_polyfill"]) if Rake::Task.task_defined?(name)
end
