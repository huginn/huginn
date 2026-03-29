class RemixConversation < ActiveRecord::Base
  self.table_name = 'remixes'
  
  belongs_to :user
  has_many :messages, class_name: 'RemixMessage', foreign_key: 'remix_id', dependent: :destroy

  validates :user, presence: true

  before_create :generate_title

  def conversation_for_api
    messages.order(:created_at).map(&:to_api_format)
  end

  private

  def generate_title
    self.title ||= "New Conversation"
  end
end
