class HomeController < ApplicationController
  skip_before_filter :authenticate_user!

  def index
  end

  def about
  end
end
