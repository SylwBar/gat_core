import Config

config :gat_core,
  env: "Dev",
  toml_config: "config/dev.toml"

config :logger,
  level: :debug,
  backends: [{LoggerFileBackend, :debug_log}, :console]

# configuration for the {LoggerFileBackend, :debug_log} backend
config :logger, :debug_log,
  format: "$time $metadata[$level] $levelpad$message\n",
  path: "debug.log"
