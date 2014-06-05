module HasGuid
  extend ActiveSupport::Concern

  included do
    before_save :make_guid
  end

  protected

  def make_guid
    self.guid = SecureRandom.hex unless guid.present?
  end
end