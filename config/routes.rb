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
      member do
        patch :transfer
      end
    end
    # Our own listings and holds (never synced with Ticketmaster).
    resources :listings, only: [ :new, :create, :edit, :update ] do
      member do
        post :verify
        post :close
      end
      collection do
        post :verify_unlisted
      end
    end
    # Hand-entered market data, for when automated research can't run.
    resources :manual_scans, only: [ :new, :create ]
  end

  # Money: what Mark owes, his Venmo payments, and the review queue.
  get "money", to: "settlements#show", as: :money
  resources :partner_payments, only: [ :index, :show, :new, :create ] do
    member do
      post :apply_suggestion
      post :allocate
      post :ignore
      post :reopen
    end
  end
  resources :settlement_allocations, only: [] do
    member { post :void }
  end

  # Patterns in the market data, and the weekly report.
  get "insights", to: "insights#show", as: :insights
  get "reports/weekly", to: "reports#weekly", as: :weekly_report

  # Market value and recommended prices; research run log.
  get "pricing", to: "pricing#index", as: :pricing
  get "pricing/map", to: "seat_maps#show", as: :seat_map
  resources :import_runs, only: [ :index, :show ]
  # Update prices: ask Duggan's computer to run the research now.
  resources :research_requests, only: [ :index, :create ] do
    member { post :cancel }
  end

  # Weekly checklist: confirm what's listed, and at what price.
  resource :listing_review, only: :show

  # Seasons history
  resources :seasons, only: [ :index ]

  # Season settings
  get "settings", to: "seasons#edit", as: :settings
  patch "settings", to: "seasons#update"
  patch "settings/pricing", to: "app_settings#update", as: :pricing_settings
  resources :api_tokens, only: [ :destroy ]

  # JSON API for the workstation skills (bearer tokens; see Api::V1::BaseController).
  namespace :api do
    namespace :v1 do
      get "research_targets", to: "research_targets#index"
      resources :import_runs, only: [ :create, :show, :update ] do
        resources :market_scans, only: [ :create ]
      end
      resources :research_requests, only: [ :show, :update ] do
        collection { post :claim }
      end
      resources :payment_imports, only: [ :create ]
      resource :settlement_summary, only: [ :show ]
      resource :weekly_report, only: [ :show ]
    end
  end

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
