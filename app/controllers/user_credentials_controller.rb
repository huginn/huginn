class UserCredentialsController < ApplicationController
  def index
    @user_credentials = current_user.user_credentials.page(params[:page])

    respond_to do |format|
      format.html
      format.json { render json: @user_credentials }
    end
  end

  def new
    @user_credential = current_user.user_credentials.build

    respond_to do |format|
      format.html
      format.json { render json: @user_credential }
    end
  end

  def edit
    @user_credential = current_user.user_credentials.find(params[:id])
  end

  def create
    @user_credential = current_user.user_credentials.build(params[:user_credential])

    respond_to do |format|
      if @user_credential.save
        format.html { redirect_to user_credentials_path, notice: 'Your credential was successfully created.' }
        format.json { render json: @user_credential, status: :created, location: @user_credential }
      else
        format.html { render action: "new" }
        format.json { render json: @user_credential.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @user_credential = current_user.user_credentials.find(params[:id])

    respond_to do |format|
      if @user_credential.update_attributes(params[:user_credential])
        format.html { redirect_to user_credentials_path, notice: 'Your credential was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @user_credential.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @user_credential = current_user.user_credentials.find(params[:id])
    @user_credential.destroy

    respond_to do |format|
      format.html { redirect_to user_credentials_path }
      format.json { head :no_content }
    end
  end
end
