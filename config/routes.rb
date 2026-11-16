Rails.application.routes.draw do
  # Authentication routes
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  # Password reset routes
  resources :password_resets, only: [ :new, :create, :edit, :update ]

  # User management routes
  resources :users do
    member do
      post :toggle_active
      get :invitation_url
      post :resend_invitation
    end
  end

  # Invitation acceptance routes
  get "accept_invitation/:token", to: "invitations#show", as: :accept_invitation
  patch "accept_invitation/:token", to: "invitations#update"

  # Buyers
  resources :buyers

  # Dashboard (root)
  root "dashboard#index"
  get "dashboard", to: "dashboard#index"

  # Games and tickets
  resources :games, only: [ :index, :show, :edit, :update, :new, :create ] do
    resources :tickets, only: [ :create, :edit, :update, :destroy ] do
      collection do
        post :bulk_create
      end
    end
  end

  # Seasons history
  resources :seasons, only: [ :index ]

  # Season settings
  get "settings", to: "seasons#edit", as: :settings
  patch "settings", to: "seasons#update"

  # Phone tab bar's "More" page
  get "more", to: "more#show", as: :more

  # Installable app: the manifest and service worker sit at the root so the
  # worker's scope covers the whole site. Rails::PwaController isn't behind
  # the login requirement, which browsers need to fetch these.
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
