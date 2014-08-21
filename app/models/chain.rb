# A Chain connects Agents in a run chain from the `runner` to the `target`.
class Chain < ActiveRecord::Base
  attr_accessible :runner_id, :target_id

  belongs_to :runner, class_name: 'Agent', inverse_of: :chains_as_runner
  belongs_to :target, class_name: 'Agent', inverse_of: :chains_as_target
end
