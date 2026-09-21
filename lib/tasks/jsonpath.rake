namespace :agents do
  desc "Migrate compatible JSONPaths; pass true to recheck Agents with use_legacy_jsonpath enabled"
  task :migrate_jsonpaths, [:recheck_legacy] => :environment do |_task, args|
    require "jsonpath_migration"

    args.with_defaults(recheck_legacy: "false")
    unless %w[true false].include?(args[:recheck_legacy])
      abort "recheck_legacy must be true or false"
    end

    JsonpathMigration.new(recheck_legacy: args[:recheck_legacy] == "true").run
  end
end
