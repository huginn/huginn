class HomeController < ApplicationController
  skip_before_action :authenticate_user!

  before_action :upgrade_warning, only: :index

  def index
  end

  def about
  end
end
