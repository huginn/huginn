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

  # Responses are authored by Agents, and thus by users, yet served from the
  # application origin.  Sandbox them so that any active content they carry
  # runs in an opaque origin, without access to the viewer's session or to
  # the application as the same origin.
  CONTENT_SECURITY_POLICY = 'sandbox allow-scripts allow-forms allow-popups'.freeze
  RESTRICTED_CONTENT_SECURITY_POLICY = "default-src 'none'; sandbox".freeze
  INLINE_CONTENT_TYPES = %w[application/json text/plain].freeze
  XML_CONTENT_TYPES = %w[application/atom+xml application/rss+xml application/xml text/xml].freeze

  def handle_request
    user = User.find_by_id(params[:user_id])
    return render plain: 'user not found', status: 404 unless user

    agent = user.agents.find_by_id(params[:agent_id])
    return render plain: 'agent not found', status: 404 unless agent

    content, status, content_type, headers = agent.trigger_web_request(request)
    headers.each { |name, value| response.headers[name] = value } if headers.present?
    status ||= 200

    unrestricted = user.admin? || ENV['ALLOW_UNRESTRICTED_AGENT_WEB_RESPONSES'] == 'true'
    response.headers['Referrer-Policy'] = 'no-referrer'

    if unrestricted
      response.headers['Content-Security-Policy'] = CONTENT_SECURITY_POLICY
    else
      response.headers['Content-Security-Policy'] = RESTRICTED_CONTENT_SECURITY_POLICY
      response.delete_header('Refresh')
      response.delete_header('Content-Type')
      response.headers['X-Content-Type-Options'] = 'nosniff'
      content_type = restricted_content_type(content_type) if content.is_a?(String)
    end

    if status.to_s.in?(%w[301 302])
      if (location = redirect_location(content, unrestricted:))
        return redirect_to(location, allow_other_host: unrestricted, status:)
      else
        return reject_redirect
      end
    end

    if !unrestricted && response.has_header?('Location')
      if (location = redirect_location(response.headers['Location'], unrestricted: false))
        response.headers['Location'] = location
      else
        return reject_redirect
      end
    end

    case content
    when String
      render plain: content, status:, content_type: content_type || 'text/plain'
    when Hash
      render(json: content, status:)
    else
      head(status)
    end
  end

  # Browser CORS preflight. Answer without authenticating or creating events so
  # the subsequent GET/POST/PUT/DELETE can proceed.
  def handle_request_options
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'POST, PUT, GET, DELETE, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = '*'
    response.headers['Access-Control-Max-Age'] = '1728000'
    render plain: 'OK'
  end

  # legacy
  def update_location
    if user = User.find_by_id(params[:user_id])
      secret = params[:secret]
      user.agents.of_type(Agents::UserLocationAgent).each do |agent|
        agent.trigger_web_request(request) if agent.options[:secret] == secret
      end
      render plain: 'ok'
    else
      render plain: 'user not found', status: :not_found
    end
  end

  private

  def redirect_location(target, unrestricted:)
    base = URI(request.original_url)
    location = base.merge(target.to_s)
    return location.to_s if unrestricted
    return unless location.is_a?(URI::HTTP) && !location.userinfo && location.origin.casecmp?(base.origin)

    location.to_s
  rescue URI::Error
    nil
  end

  def reject_redirect
    response.delete_header('Location')
    head :forbidden
  end

  def restricted_content_type(content_type)
    mime_type = content_type.to_s[/\A\s*([^;\s]+)\s*(?:;|\z)/, 1]&.downcase
    if XML_CONTENT_TYPES.include?(mime_type)
      response.headers['Content-Disposition'] = 'attachment'
      mime_type
    elsif INLINE_CONTENT_TYPES.include?(mime_type)
      mime_type
    else
      'text/plain'
    end
  end
end
