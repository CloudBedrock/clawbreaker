import Config

# Default configuration
config :clawbreaker,
  url: "https://api.clawbreaker.dev"

# Import environment specific config
import_config "#{config_env()}.exs"
