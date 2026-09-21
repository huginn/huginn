require "jsonpath_migration"

# Switch compatible paths to RFC 9535 while preserving uncertain legacy queries.
class NormalizeAgentJsonpaths < ActiveRecord::Migration[8.1]
  def up
    JsonpathMigration.new(output: method(:say)).run
  end

  def down
    # Normalized paths also work with the legacy evaluator.
  end
end
