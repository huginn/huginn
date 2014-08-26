class HomeController < ApplicationController
  skip_before_filter :authenticate_user!

  before_filter :upgrade_warning, only: :index

  def index
  end

  def about
  end
end
