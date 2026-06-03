Rails.application.routes.draw do
  # Health check (kamal-proxy) + PWA - OUTSIDE the locale scope (hit without a locale prefix).
  get "/up", to: "rails/health#show", as: :rails_health_check
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Map geometry served from disk - locale-independent, like /up.
  get "/geo/:name", to: "geo#show", format: false, constraints: { name: /[a-z0-9_\-]+\.geojson/i }

  # PVAR compute layer: create a run + poll its status as JSON. Locale-independent (the Stimulus
  # controller fetches these from any locale prefix), like /geo and /up.
  resources :analyses, only: [:index, :create, :show, :destroy]

  # Indicator coverage map (country -> run-length year ranges) for instant client-side configurator validation
  #. Query param (codes contain dots, e.g. NY.GDP.PCAP.KD). Locale-independent like /analyses.
  get "indicators/coverage", to: "indicators#coverage"

  # Locale-scoped app routes. Optional prefix: "/" → detected locale, "/pl|/en|/es" → explicit.
  # Adding a language = add it to config.i18n.available_locales; this regex picks it up automatically.
  scope "(:locale)", locale: /#{I18n.available_locales.join("|")}/ do
    root "pages#main"
    get "system-info", to: "pages#system_info", as: :system_info
    get "upload", to: "pages#upload", as: :upload_page
    get "methodology", to: "pages#methodology", as: :methodology

    namespace :api do
      get "observations", to: "observations#index"
    end
  end
end
