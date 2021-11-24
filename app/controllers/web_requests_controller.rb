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
# Your Agent's #receive_web_request method should return an Array of json_or_string_response, status_code, 
# optional mime type, and optional hash of custom response headers.  For example:
#   [{status: "success"}, 200]
# or
#   ["not found", 404, 'text/plain']
# or
#   ["<status>success</status>", 200, 'text/xml', {"Access-Control-Allow-Origin" => "*"}]

class WebRequestsController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  wrap_parameters false

  def handle_request
    user = User.find_by_id(params[:user_id])
    if user
      agent = user.agents.find_by_id(params[:agent_id])
      if agent
        content, status, content_type, headers = agent.trigger_web_request(request)

        if headers.present?
          headers.each do |k,v|
            response.headers[k] = v
          end
        end

        status = status || 200

        if status.to_s.in?(["301", "302"])
          redirect_to content, status: status
        elsif content.is_a?(String)
          render plain: content, :status => status, :content_type => content_type || 'text/plain'
        elsif content.is_a?(Hash)
          render :json => content, :status => status
        else
          head(status)
        end
      else
        render plain: "agent not found", :status => 404
      end
    else
      render plain: "user not found", :status => 404
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
      render plain: "ok"
    else
      render plain: "user not found", :status => :not_found
    end
  end
end
