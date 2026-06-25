# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users, defaults: { format: :json }, controllers: {
    sessions: "users/sessions"
  }

  devise_scope :user do
    get "user/profile" => "users/sessions#show"
    get "user/me" => "users/sessions#show"
    get "user/whoami" => "users/sessions#show"
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"

  match "*path", to: "application#route_not_found", via: :all
end
