import Config

config :gat_core,
  test_key1: "value1"

import_config "#{config_env()}.exs"
