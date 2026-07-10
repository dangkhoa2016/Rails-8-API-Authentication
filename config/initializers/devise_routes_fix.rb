# frozen_string_literal: true

# Devise (<= 5.0.4) passes options as a hash to resource(),
# which Rails 8.1+ deprecates in favor of keyword arguments.
# This monkey-patch updates the internal methods to use
# keyword arguments directly, silencing the deprecation warning.

module DeviseRoutesKeywordFix
  def devise_session(mapping, controllers)
    resource :session, only: [], controller: controllers[:sessions], path: "" do
      get   :new,     path: mapping.path_names[:sign_in],  as: "new"
      post  :create,  path: mapping.path_names[:sign_in]
      match :destroy, path: mapping.path_names[:sign_out], as: "destroy", via: mapping.sign_out_via
    end
  end

  def devise_password(mapping, controllers)
    resource :password, only: [:new, :create, :edit, :update],
      path: mapping.path_names[:password], controller: controllers[:passwords]
  end

  def devise_confirmation(mapping, controllers)
    resource :confirmation, only: [:new, :create, :show],
      path: mapping.path_names[:confirmation], controller: controllers[:confirmations]
  end

  def devise_registration(mapping, controllers)
    path_names = {
      new: mapping.path_names[:sign_up],
      edit: mapping.path_names[:edit],
      cancel: mapping.path_names[:cancel]
    }

    resource :registration, only: [:new, :create, :edit, :update, :destroy],
      path: mapping.path_names[:registration],
      path_names: path_names,
      controller: controllers[:registrations] do
        get :cancel
      end
  end
end

ActionDispatch::Routing::Mapper.prepend(DeviseRoutesKeywordFix)
