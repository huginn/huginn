# This controller is designed to allow your Agents to receive cross-site Webhooks (POSTs), or to output data streams.
# When a POST or GET is received, your Agent will have #receive_webhook called on itself with the incoming params.
#
# To implement webhooks, make POSTs to the following URL:
#   http://yourserver.com/users/:user_id/webhooks/:agent_id/:secret
# where :user_id is your User's id, :agent_id is an Agent's id, and :secret is a token that should be
# user-specifiable in your Agent.  It is highly recommended that you verify this token whenever #receive_webhook
# is called.  For example, one of your Agent's options could be :secret and you could compare this value
# to params[:secret] whenever #receive_webhook is called on your Agent, rejecting invalid requests.
#
# Your Agent's #receive_webhook method should return an Array of [json_or_string_response, status_code, optional mime type].  For example:
#   [{status: "success"}, 200]
# or
#   ["not found", 404, 'text/plain']

class WebhooksController < ApplicationController
  skip_before_filter :authenticate_user!

  def handle_request
    user = User.find_by_id(params[:user_id])
    if user
      agent = user.agents.find_by_id(params[:agent_id])
      if agent
        content, status, content_type = agent.trigger_webhook(params.except(:action, :controller, :agent_id, :user_id, :format), request.method_symbol.to_s, request.format.to_s)
        if content.is_a?(String)
          render :text => content, :status => status || 200, :content_type => content_type || 'text/plain'
        elsif content.is_a?(Hash)
          render :json => content, :status => status || 200
        else
          head(status || 200)
        end
      else
        render :text => "agent not found", :status => 404
      end
    else
      render :text => "user not found", :status => 404
    end
  end
end
