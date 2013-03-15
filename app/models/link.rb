# == Schema Information
#
# Table name: links
#
#  id          :integer          not null, primary key
#  source_id   :integer
#  receiver_id :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

class Link < ActiveRecord::Base
  attr_accessible :source_id, :receiver_id

  belongs_to :source, :class_name => "Agent", :inverse_of => :links_as_source
  belongs_to :receiver, :class_name => "Agent", :inverse_of => :links_as_receiver
end
