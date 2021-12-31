defmodule OGNCore.Config do
  require Logger

  @default_core_server_port 8701
  @default_core_server_max_conn 500
  @default_aprs_server_port 14580
  @default_aprs_server_id 999

  def read_toml(toml_file) do
    try do
      Logger.info("Reading configuration file: #{toml_file}")
      toml_config = Toml.decode_file!(toml_file)

      core_config = Map.get(toml_config, "Core")

      if core_config == nil do
        raise "No Core configuration provided in configuration file"
      end

      core_server_name = Map.get(core_config, "server_name")

      if core_server_name == nil do
        raise "No server name provided in configuration file"
      end

      core_server_port = Map.get(core_config, "server_port", @default_core_server_port)

      core_server_max_conn =
        Map.get(core_config, "server_max_conn", @default_core_server_max_conn)

      Logger.info("OGN Core server name: #{core_server_name}")
      aprs_config = Map.get(toml_config, "APRS")

      if aprs_config == nil do
        raise "No APRS configuration provided in configuration file"
      end

      aprs_server_addr = Map.get(aprs_config, "server_addr")

      if aprs_server_addr == nil do
        raise "No APRS server address provided in configuration file"
      end

      aprs_server_port = Map.get(aprs_config, "server_port", @default_aprs_server_port)
      aprs_client_id = Map.get(aprs_config, "client_id", @default_aprs_server_id)

      :ets.new(:ogn_core_config, [:set, :protected, :named_table])
      :ets.insert(:ogn_core_config, {:config_file, toml_file})
      :ets.insert(:ogn_core_config, {:core_server_name, core_server_name})
      :ets.insert(:ogn_core_config, {:core_server_port, core_server_port})
      :ets.insert(:ogn_core_config, {:core_server_max_conn, core_server_max_conn})
      :ets.insert(:ogn_core_config, {:aprs_server_addr, aprs_server_addr})
      :ets.insert(:ogn_core_config, {:aprs_server_port, aprs_server_port})
      :ets.insert(:ogn_core_config, {:aprs_client_id, aprs_client_id})

      :ok
    rescue
      e in RuntimeError -> {:error, e}
      e in ArgumentError -> {:error, e}
      e in File.Error -> {:error, e}
      e in Toml.Error -> {:error, e}
    end
  end

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
end
