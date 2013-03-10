class Contact < ActiveRecord::Base
  attr_accessible :email, :message, :name

  validates_format_of :email, :with => /\A[A-Z0-9._%+-]+@[A-Z0-9.-]+\.(?:[A-Z]{2}|com|org|net|edu|gov|mil|biz|info|mobi|name|aero|asia|jobs|museum)\Z/i
  validates_presence_of :name, :message

  after_create :send_contact

  def send_contact
    ContactMailer.send_contact(self).deliver
  end
end