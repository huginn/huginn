class HomeController < ApplicationController
  skip_before_filter :authenticate_user!

  before_filter :upgrade_warning, only: :index

  def index
  end

  def about
  end

  private
  def upgrade_warning
    return unless current_user
    twitter_oauth_check
    basecamp_auth_check
  end

  def twitter_oauth_check
    if ENV['TWITTER_OAUTH_KEY'].blank? || ENV['TWITTER_OAUTH_SECRET'].blank?
      if @twitter_agent = current_user.agents.where("type like 'Agents::Twitter%'").first
        @twitter_oauth_key    = @twitter_agent.options['consumer_key'].presence || @twitter_agent.credential('twitter_consumer_key')
        @twitter_oauth_secret = @twitter_agent.options['consumer_secret'].presence || @twitter_agent.credential('twitter_consumer_secret')
      end
    end
  end

  def basecamp_auth_check
    if ENV['THIRTY_SEVEN_SIGNALS_OAUTH_KEY'].blank? || ENV['THIRTY_SEVEN_SIGNALS_OAUTH_SECRET'].blank?
      @basecamp_agent = current_user.agents.where(type: 'Agents::BasecampAgent').first
    end
  end
end
