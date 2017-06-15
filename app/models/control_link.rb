# A ControlLink connects Agents in a control flow from the `controller` to the `control_target`.
class ControlLink < ActiveRecord::Base
  belongs_to :controller, class_name: 'Agent', inverse_of: :control_links_as_controller
  belongs_to :control_target, class_name: 'Agent', inverse_of: :control_links_as_control_target
end
