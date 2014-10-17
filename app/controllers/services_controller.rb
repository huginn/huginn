class ServicesController < ApplicationController
  include SortableTable

  before_action :upgrade_warning, only: :index

  def index
    set_table_sort sorts: %w[provider name global], default: { provider: :asc }

    @services = current_user.services.reorder(table_sort).page(params[:page])

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
end
