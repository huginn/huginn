# A Chain connects Agents in a run chain from the `controller` to the `target`.
class Chain < ActiveRecord::Base
  attr_accessible :controller_id, :target_id

  belongs_to :controller, class_name: 'Agent', inverse_of: :chains_as_controller
  belongs_to :target, class_name: 'Agent', inverse_of: :chains_as_target
end
