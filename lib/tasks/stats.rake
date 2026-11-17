require_relative "../container_downloads"

namespace :stats do
  namespace :containers do
    desc "Collect container download counters into a JSON snapshot"
    task :collect, [:output] do |_task, args|
      abort "stats:containers:collect: output file is required" unless args[:output]

      ContainerDownloads.write_json(args[:output], ContainerDownloads.collect)
    rescue ContainerDownloads::Error, SystemCallError => e
      abort "stats:containers:collect: #{e.message}"
    end

    desc "Append a container snapshot to history and update summaries and badge"
    task :record, [:snapshot, :directory] do |_task, args|
      abort "stats:containers:record: snapshot file and output directory are required" unless args[:snapshot] && args[:directory]

      ContainerDownloads.store(JSON.parse(File.read(args[:snapshot])), args[:directory])
    rescue ContainerDownloads::Error, JSON::ParserError, SystemCallError => e
      abort "stats:containers:record: #{e.message}"
    end
  end
end
