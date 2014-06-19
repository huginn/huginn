class ScenarioMembership < ActiveRecord::Base
  belongs_to :agent, :inverse_of => :scenario_memberships
  belongs_to :scenario, :inverse_of => :scenario_memberships
end
