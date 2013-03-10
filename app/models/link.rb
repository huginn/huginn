class Link < ActiveRecord::Base
  attr_accessible :source_id, :receiver_id

  belongs_to :source, :class_name => "Agent", :inverse_of => :links_as_source
  belongs_to :receiver, :class_name => "Agent", :inverse_of => :links_as_receiver
end
