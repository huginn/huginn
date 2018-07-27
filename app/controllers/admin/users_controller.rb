class Admin::UsersController < ApplicationController
  before_action :authenticate_admin!, except: [:switch_back]

  before_action :find_user, only: [:edit, :destroy, :update, :deactivate, :activate, :switch_to_user]

  helper_method :resource

  def index
    @users = User.reorder('created_at DESC').page(params[:page])

    respond_to do |format|
      format.html
      format.json { render json: @users }
    end
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    @user.requires_no_invitation_code!

    respond_to do |format|
      if @user.save
        DefaultScenarioImporter.import(@user)    
        format.html { redirect_to admin_users_path, notice: "User '#{@user.username}' was successfully created." }
        format.json { render json: @user, status: :ok, location: admin_users_path(@user) }
      else
        format.html { render action: 'new' }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    params[:user].extract!(:password, :password_confirmation) if params[:user][:password].blank?
    @user.assign_attributes(user_params)

    respond_to do |format|
      if @user.save
        format.html { redirect_to admin_users_path, notice: "User '#{@user.username}' was successfully updated." }
        format.json { render json: @user, status: :ok, location: admin_users_path(@user) }
      else
        format.html { render action: 'edit' }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @user.destroy

    respond_to do |format|
      format.html { redirect_to admin_users_path, notice: "User '#{@user.username}' was deleted." }
      format.json { head :no_content }
    end
  end

  def deactivate
    @user.deactivate!

    respond_to do |format|
      format.html { redirect_to admin_users_path, notice: "User '#{@user.username}' was deactivated." }
      format.json { render json: @user, status: :ok, location: admin_users_path(@user) }
    end
  end

  def activate
    @user.activate!

    respond_to do |format|
      format.html { redirect_to admin_users_path, notice: "User '#{@user.username}' was activated." }
      format.json { render json: @user, status: :ok, location: admin_users_path(@user) }
    end
  end

  # allow an admin to sign-in as any other user

  def switch_to_user
    if current_user != @user
      old_user = current_user
      bypass_sign_in(@user)
      session[:original_admin_user_id] = old_user.id
    end
    redirect_to agents_path
  end

  def switch_back
    if session[:original_admin_user_id].present?
      bypass_sign_in(User.find(session[:original_admin_user_id]))
      session.delete(:original_admin_user_id)
    else
      redirect_to(root_path, alert: 'You must be an admin acting as a different user to do that.') and return
    end
    redirect_to admin_users_path
  end

  private

  def user_params
    params.require(:user).permit(:email, :username, :password, :password_confirmation, :admin)
  end

  def find_user
    @user = User.find(params[:id])
  end

  def resource
    @user
  end
end
