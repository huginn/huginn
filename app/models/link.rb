# A Link connects Agents in a directed Event flow from the `source` to the `receiver`.
class Link < ActiveRecord::Base
  belongs_to :source, :class_name => "Agent", :inverse_of => :links_as_source
  belongs_to :receiver, :class_name => "Agent", :inverse_of => :links_as_receiver

  before_create :store_event_id_at_creation

  def store_event_id_at_creation
    self.event_id_at_creation = source.events.limit(1).reorder("id desc").pluck(:id).first || 0
  end
end
