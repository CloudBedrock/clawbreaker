import Config

# Default configuration
config :clawbreaker,
  url: "https://api.clawbreaker.ai"

# Import environment specific config
import_config "#{config_env()}.exs"
