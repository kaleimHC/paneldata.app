source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.6"
# Indicator hierarchy via materialized-path tree (D-046 / D-139 / D-140)
gem "ancestry", "~> 5.1"
# CSV is a bundled (no longer default) gem as of Ruby 3.4 - used by data fetchers (cache I/O)
gem "csv"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Component objects for the view layer (D-172 Layer 2, Sidecar pattern)
gem "view_component", "~> 4.0"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"
# CLDR locale data (plural rules, date/number formats, default messages) for all locales - i18n (D-102/D-177)
gem "rails-i18n"
# Use Redis adapter to run Action Cable in production
# gem "redis", ">= 4.0.1"

# Background jobs for the live PVAR compute layer (UD-14 / D-037): Sidekiq + Redis accessory.
# pvar_jobs queue runs the R shell-out (Open3 + Timeout). Sidekiq bundles redis-client (no separate redis gem).
gem "sidekiq", "~> 8.0"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false
# net-ssh (kamal's SSH) needs x25519 to negotiate curve25519-sha256 kex against the curve25519-only hardened sshd
gem "x25519", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Detect missing/unused i18n translations in CI (D-177 coverage tracking)
  gem "i18n-tasks", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end
