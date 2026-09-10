require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = true

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.


  # --------------------------------------------------
  # Action Mailer — Resend (smtp.resend.com)
  #
  # Without this block Rails falls back to its default of SMTP on
  # localhost:25. There is no mail server inside the app container, so
  # every delivery raised Errno::ECONNREFUSED in Sidekiq and no mail ever
  # reached Resend. This is what was breaking production email.
  # --------------------------------------------------

  config.action_mailer.perform_deliveries = true

  # Surface delivery failures. Mail goes out through Sidekiq, so an
  # exception here is retried and shows up in the worker log and Sentry
  # instead of disappearing.
  config.action_mailer.raise_delivery_errors = true

  # Host used by links generated in mailer templates (invitations,
  # password resets, ticket links). Must be https in production.
  config.action_mailer.default_url_options = { host: "salato.app", protocol: "https" }
  config.action_mailer.asset_host = "https://salato.app"

  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: "smtp.resend.com",
    port:    587,

    # Resend's SMTP username is the literal string "resend" for every
    # account — NOT the sending address. The API key is the password.
    user_name: "resend",
    password:  ENV["RESEND_API_KEY"].presence ||
               Rails.application.credentials.dig(:resend, :api_key),

    authentication:       :plain,
    enable_starttls_auto: true,
    open_timeout:         10,
    read_timeout:         10
  }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
