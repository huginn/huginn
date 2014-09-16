class UserLocationUpdatesController < ApplicationController
  skip_before_filter :authenticate_user!

  def create
    user = User.find_by_id(params[:user_id])
    if user
      secret = params[:secret]
      user.agents.of_type(Agents::UserLocationAgent).find_all {|agent| agent.options[:secret] == secret }.each do |agent|
        agent.trigger_web_request(params.except(:action, :controller, :user_id, :format), request.method_symbol.to_s, request.format.to_s)
      end
      render :text => "ok"
    else
      render :text => "user not found", :status => :not_found
    end
  end
end
