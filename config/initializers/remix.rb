# Configure Zeitwerk to ignore tools, skills, and tool_registry
# (tools/skills files define multiple classes per file, which doesn't match Zeitwerk conventions)
# (tool_registry must be loaded after tools are defined)
Rails.autoloaders.main.ignore(Rails.root.join('app', 'models', 'remix', 'tools'))
Rails.autoloaders.main.ignore(Rails.root.join('app', 'models', 'remix', 'skills'))
Rails.autoloaders.main.ignore(Rails.root.join('app', 'models', 'remix', 'tool_registry.rb'))

# Load Remix tool and skill classes
Rails.application.config.to_prepare do
  # Load base classes first
  require_dependency Rails.root.join('app', 'models', 'remix', 'tools', 'base_tool.rb').to_s
  require_dependency Rails.root.join('app', 'models', 'remix', 'skills', 'base_skill.rb').to_s
  
  # Then load all other tools and skills
  Dir[Rails.root.join('app', 'models', 'remix', 'tools', '*.rb')].sort.each do |f|
    next if f.end_with?('base_tool.rb')
    require_dependency f
  end
  
  Dir[Rails.root.join('app', 'models', 'remix', 'skills', '*.rb')].sort.each do |f|
    next if f.end_with?('base_skill.rb')
    require_dependency f
  end
  
  # Load tool_registry AFTER all tools are defined
  require_dependency Rails.root.join('app', 'models', 'remix', 'tool_registry.rb').to_s
end


