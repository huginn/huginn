class UserLocationUpdatesController < ApplicationController
  skip_before_filter :authenticate_user!

  def create
    user = User.find_by_id(params[:user_id])
    if user
      secret = params[:secret]
      user.agents.of_type(Agents::UserLocationAgent).find_all {|agent| agent.options[:secret] == secret }.each do |agent|
        agent.create_event :payload => params.except(:controller, :action, :secret, :user_id, :format),
                           :lat => params[:latitude],
                           :lng => params[:longitude]
      end
      render :text => "ok"
    else
      render :text => "user not found", :status => :not_found
    end
  end
end
