class MigrateScenarioIconToFontAwesome5 < ActiveRecord::Migration[6.0]
  MAP = [
    ['gear', 'cog'],
    ['gears', 'cogs'],
    ['glass', 'glass-martini'],
    ['automobile', 'car'],
    ['clock-o', 'clock'],
    ['spoon', 'utensil-spoon'],
    ['video-camera', 'video'],
    ['photo', 'image'],
    ['dashboard', 'tachometer-alt'],
    ['gears', 'cogs'],
    ['tachometer', 'tachometer-alt'],
    ['bank', 'university'],
    ['cutlery', 'utensils'],
    ['pencil', 'pencil-alt'],
    ['scissors', 'cut']
  ]

  def up
    MAP.each do |old_name, new_name|
      Scenario.where(icon: old_name).update_all(icon: new_name)
    end
  end

  def down
    MAP.each do |old_name, new_name|
      Scenario.where(icon: new_name).update_all(icon: old_name)
    end
  end
end
