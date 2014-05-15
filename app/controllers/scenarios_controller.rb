class ScenariosController < ApplicationController
  def index
    @scenarios = current_user.scenarios.page(params[:page])

    respond_to do |format|
      format.html
      format.json { render json: @scenarios }
    end
  end

  def new
    @scenario = current_user.scenarios.build

    respond_to do |format|
      format.html
      format.json { render json: @scenario }
    end
  end

  def show
    @scenario = current_user.scenarios.find(params[:id])
    @agents = @scenario.agents.preload(:scenarios).page(params[:page])

    respond_to do |format|
      format.html
      format.json { render json: @scenario }
    end
  end

  # Share is a work in progress!
  def share
    @scenario = current_user.scenarios.find(params[:id])
    @agents = @scenario.agents.preload(:scenarios).page(params[:page])

    respond_to do |format|
      format.html
      format.json { render json: @scenario }
    end
  end

  def edit
    @scenario = current_user.scenarios.find(params[:id])

    respond_to do |format|
      format.html
      format.json { render json: @scenario }
    end
  end

  def create
    @scenario = current_user.scenarios.build(params[:scenario])

    respond_to do |format|
      if @scenario.save
        format.html { redirect_to @scenario, notice: 'This Scenario was successfully created.' }
        format.json { render json: @scenario, status: :created, location: @scenario }
      else
        format.html { render action: "new" }
        format.json { render json: @scenario.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @scenario = current_user.scenarios.find(params[:id])

    respond_to do |format|
      if @scenario.update_attributes(params[:scenario])
        format.html { redirect_to @scenario, notice: 'This Scenario was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @scenario.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @scenario = current_user.scenarios.find(params[:id])
    @scenario.destroy

    respond_to do |format|
      format.html { redirect_to scenarios_path }
      format.json { head :no_content }
    end
  end
end
