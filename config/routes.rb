# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users, defaults: { format: :json }, controllers: {
    sessions: "users/sessions",
    registrations: "users/registrations",
    passwords: "users/passwords"
  }

  devise_scope :user do
    # Primary profile endpoint.
    get "user/profile" => "users/sessions#show"
    # Compatibility aliases — deprecated. Remove after confirming no active clients rely on them.
    get "user/me"     => "users/sessions#show"
    get "user/whoami" => "users/sessions#show"
  end

  resources :users, only: [ :index, :update, :destroy, :show ], defaults: { format: :json }
  post "users/create" => "users#create", as: :users_create, defaults: { format: :json }
  put "users/:id/status" => "users#toggle_status", constraints: { id: /[^\/?#]+/ }, defaults: { format: :json }
  put "users/:id/confirm_by_admin" => "users#confirm_by_admin", constraints: { id: /[^\/?#]+/ }, defaults: { format: :json }

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root "home#index"

  match "*path", to: "application#route_not_found", via: :all unless Rails.env.development?
end
