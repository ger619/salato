Sentry.init do |config|
  config.dsn = 'https://54a973eba0b07f60398de92866e16de6@o4507601057808384.ingest.de.sentry.io/4512005723455568'
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  # Don't send buyers' names, emails or phone numbers to Sentry.
  config.send_default_pii = false

  # Sentry 7 sends logs automatically, so enable_logs is gone.
  # Patch Ruby logger to forward logs
  config.enabled_patches = [:logger]

  # Capture 100% of transactions for tracing. Lower this later if Sentry gets expensive.
  config.traces_sample_rate = 1.0
  config.profiles_sample_rate = 1.0
end