module WeiboConcern
  extend ActiveSupport::Concern

  included do
    self.validate :validate_weibo_options
  end

  def validate_weibo_options
    errors.add(:base, "access_token is required") unless options["access_token"].present?
  end

  def weibo_client
    @weibo_client ||= WeiboApiClient.new(access_token: options['access_token'])
  end
end
