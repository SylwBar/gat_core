import Config

config :gat_core,
  env: "Release",
  toml_config: "config/prod.toml"

config :logger,
  level: :info,
  utc_log: true,
  backends: [{LoggerFileBackend, :info_log}]

# configuration for the {LoggerFileBackend, :info_log} backend
config :logger, :info_log,
  format: "$date $time $metadata[$level] $levelpad$message\n",
  path: "gat_core.log"
