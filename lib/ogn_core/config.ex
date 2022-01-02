defmodule OGNCore.Config do
  require Logger

  @default_core_server_port 8701
  @default_core_server_max_conn 500
  @default_aprs_server_port 14580
  @default_aprs_server_id 999

  @default_mqtt_server_port 1883

  def read_toml(toml_file) do
    try do
      :ets.new(:ogn_core_config, [:set, :protected, :named_table])
      Logger.info("Reading configuration file: #{toml_file}")
      toml_config = Toml.decode_file!(toml_file)
      :ets.insert(:ogn_core_config, {:config_file, toml_file})

      # -------- CORE Config --------
      core_config = Map.get(toml_config, "Core")

      if core_config == nil, do: raise("No Core configuration provided in configuration file")

      core_server_name = Map.get(core_config, "server_name")

      if core_server_name == nil, do: raise("No server name provided in configuration file")

      core_server_port = Map.get(core_config, "server_port", @default_core_server_port)

      core_server_max_conn =
        Map.get(core_config, "server_max_conn", @default_core_server_max_conn)

      :ets.insert(:ogn_core_config, {:core_server_name, core_server_name})
      :ets.insert(:ogn_core_config, {:core_server_port, core_server_port})
      :ets.insert(:ogn_core_config, {:core_server_max_conn, core_server_max_conn})

      # -------- APRS Config --------

      aprs_config = Map.get(toml_config, "APRS")

      if aprs_config == nil, do: raise("No APRS configuration provided in configuration file")

      aprs_server_addr = Map.get(aprs_config, "server_addr")

      if aprs_server_addr == nil,
        do: raise("No APRS server address provided in configuration file")

      aprs_server_port = Map.get(aprs_config, "server_port", @default_aprs_server_port)
      aprs_client_id = Map.get(aprs_config, "client_id", @default_aprs_server_id)

      :ets.insert(:ogn_core_config, {:aprs_server_addr, aprs_server_addr})
      :ets.insert(:ogn_core_config, {:aprs_server_port, aprs_server_port})
      :ets.insert(:ogn_core_config, {:aprs_client_id, aprs_client_id})

      # -------- MQTT Config --------
      mqtt_config = Map.get(toml_config, "MQTT")
      if mqtt_config == nil, do: raise("No MQTT configuration provided in configuration file")

      mqtt_enabled = Map.get(mqtt_config, "enabled", true)
      :ets.insert(:ogn_core_config, {:mqtt_enabled, mqtt_enabled})

      if mqtt_enabled do
        mqtt_server_addr = Map.get(mqtt_config, "server_addr")

        if mqtt_server_addr == nil,
          do: raise("No MQTT server address provided in configuration file")

        mqtt_server_port = Map.get(mqtt_config, "server_port", @default_mqtt_server_port)
        mqtt_user_name = Map.get(mqtt_config, "user_name")
        mqtt_password = Map.get(mqtt_config, "password")

        :ets.insert(:ogn_core_config, {:mqtt_server_addr, mqtt_server_addr})
        :ets.insert(:ogn_core_config, {:mqtt_server_port, mqtt_server_port})
        :ets.insert(:ogn_core_config, {:mqtt_user_name, mqtt_user_name})
        :ets.insert(:ogn_core_config, {:mqtt_password, mqtt_password})
      end

      Logger.info("OGN Core server name: #{core_server_name}, configuration OK.")

      :ok
    rescue
      e in RuntimeError -> {:error, e}
      e in ArgumentError -> {:error, e}
      e in File.Error -> {:error, e}
      e in Toml.Error -> {:error, e}
    end
  end

  # -------- CORE Config --------

  def get_core_server_name() do
    [core_server_name: core_server_name] = :ets.lookup(:ogn_core_config, :core_server_name)

    core_server_name
  end

  def get_core_server_port() do
    [core_server_port: core_server_port] = :ets.lookup(:ogn_core_config, :core_server_port)

    core_server_port
  end

  def get_core_server_max_conn() do
    [core_server_max_conn: core_server_max_conn] =
      :ets.lookup(:ogn_core_config, :core_server_max_conn)

    core_server_max_conn
  end

  # -------- APRS Config --------

  def get_aprs_server_addr() do
    [aprs_server_addr: server_addr] = :ets.lookup(:ogn_core_config, :aprs_server_addr)
    server_addr
  end

  def get_aprs_server_port() do
    [aprs_server_port: server_port] = :ets.lookup(:ogn_core_config, :aprs_server_port)
    server_port
  end

  def get_aprs_client_id() do
    [aprs_client_id: client_id] = :ets.lookup(:ogn_core_config, :aprs_client_id)
    client_id
  end

  # -------- MQTT Config --------
  def get_mqtt_enabled() do
    [mqtt_enabled: enabled] = :ets.lookup(:ogn_core_config, :mqtt_enabled)
    enabled
  end

  def get_mqtt_server_addr() do
    [mqtt_server_addr: server_addr] = :ets.lookup(:ogn_core_config, :mqtt_server_addr)
    server_addr
  end

  def get_mqtt_server_port() do
    [mqtt_server_port: server_port] = :ets.lookup(:ogn_core_config, :mqtt_server_port)
    server_port
  end

  def get_mqtt_user_name() do
    [mqtt_user_name: user_name] = :ets.lookup(:ogn_core_config, :mqtt_user_name)
    user_name
  end

  def get_mqtt_password() do
    [mqtt_password: password] = :ets.lookup(:ogn_core_config, :mqtt_password)
    password
  end
end
