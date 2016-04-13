# This controller is designed to allow your Agents to receive cross-site Webhooks (POSTs), or to output data streams.
# When a POST or GET is received, your Agent will have #receive_web_request called on itself with the incoming params,
# method, and requested content-type.
#
# Requests are routed as follows:
#   http://yourserver.com/users/:user_id/web_requests/:agent_id/:secret
# where :user_id is a User's id, :agent_id is an Agent's id, and :secret is a token that should be user-specifiable in
# an Agent that implements #receive_web_request. It is highly recommended that every Agent verify this token whenever
# #receive_web_request is called. For example, one of your Agent's options could be :secret and you could compare this
# value to params[:secret] whenever #receive_web_request is called on your Agent, rejecting invalid requests.
#
# Your Agent's #receive_web_request method should return an Array of json_or_string_response, status_code, and
# optional mime type.  For example:
#   [{status: "success"}, 200]
# or
#   ["not found", 404, 'text/plain']

class WebRequestsController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!

  def handle_request
    user = User.find_by_id(params[:user_id])
    if user
      agent = user.agents.find_by_id(params[:agent_id])
      if agent
        content, status, content_type = agent.trigger_web_request(request)

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

  # legacy
  def update_location
    if user = User.find_by_id(params[:user_id])
      secret = params[:secret]
      user.agents.of_type(Agents::UserLocationAgent).each { |agent|
        if agent.options[:secret] == secret
          agent.trigger_web_request(request)
        end
      }
      render :text => "ok"
    else
      render :text => "user not found", :status => :not_found
    end
  end
end
