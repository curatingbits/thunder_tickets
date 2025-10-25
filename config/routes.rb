Rails.application.routes.draw do
  # Authentication routes
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  # Password reset routes
  resources :password_resets, only: [:new, :create, :edit, :update]

  # Dashboard (root)
  root "dashboard#index"
  get "dashboard", to: "dashboard#index"

  # Games and tickets
  resources :games, only: [:index, :show, :edit, :update, :new, :create] do
    resources :tickets, only: [:create, :destroy]
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
