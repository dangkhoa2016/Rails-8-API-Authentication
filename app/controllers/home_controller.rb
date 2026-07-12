# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    render json: { message: I18n.t("home.welcome") }
  end
end
