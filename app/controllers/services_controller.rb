class ServicesController < ApplicationController
  before_filter :upgrade_warning, only: :index

  def index
    @services = current_user.services.page(params[:page])

    respond_to do |format|
      format.html
      format.json { render json: @services }
    end
  end

  def destroy
    @services = current_user.services.find(params[:id])
    @services.destroy

    respond_to do |format|
      format.html { redirect_to services_path }
      format.json { head :no_content }
    end
  end

  def toggle_availability
    @service = current_user.services.find(params[:id])
    @service.toggle_availability!

    respond_to do |format|
      format.html { redirect_to services_path }
      format.json { render json: @service }
    end
  end

  def callback
    @service = current_user.services.initialize_or_update_via_omniauth(request.env['omniauth.auth'])
    if @service && @service.save
      redirect_to services_path, notice: "The service was successfully created."
    else
      redirect_to services_path, error: "Error creating the service."
    end
  end
end
