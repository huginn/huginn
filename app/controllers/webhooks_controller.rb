# This controller is designed to allow your Agents to receive cross-site Webhooks (posts).  When POSTed, your Agent will
# have #receive_webhook called on itself with the POST params.
#
# Make POSTs to the following URL:
#   http://yourserver.com/users/:user_id/webhooks/:agent_id/:secret
# where :user_id is your User's id, :agent_id is an Agent's id, and :secret is a token that should be
# user-specifiable in your Agent.  It is highly recommended that you verify this token whenever #receive_webhook
# is called.  For example, one of your Agent's options could be :secret and you could compare this value
# to params[:secret] whenever #receive_webhook is called on your Agent, rejecting invalid requests.
#
# Your Agent's #receive_webhook method should return an Array of [json_or_string_response, status_code].  For example:
#   [{status: "success"}, 200]
# or
#   ["not found", 404]

class WebhooksController < ApplicationController
  skip_before_filter :authenticate_user!

  def create
    user = User.find_by_id(params[:user_id])
    if user
      agent = user.agents.find_by_id(params[:agent_id])
      if agent
        response, status = agent.trigger_webhook(params.except(:action, :controller, :agent_id, :user_id))
        if response.is_a?(String)
          render :text => response, :status => status || 200
        elsif response.is_a?(Hash)
          render :json => response, :status => status || 200
        else
          head :ok
        end
      else
        render :text => "agent not found", :status => :not_found
      end
    else
      render :text => "user not found", :status => :not_found
    end
  end
end
