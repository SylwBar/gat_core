defmodule GATCore.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    env = Application.fetch_env!(:gat_core, :env)
    ver = Application.spec(:gat_core, :vsn) |> to_string()
    Logger.info("GAT Core #{ver} #{env}")
    toml_file = Application.fetch_env!(:gat_core, :toml_config)
    :ok = GATCore.Config.read_toml(toml_file)
    {:ok, :objects_data} = :dets.open_file(:objects_data, type: :set, file: 'object_data.dets')

    tortoise_child =
      case GATCore.Config.get_mqtt_enabled() do
        true -> [{Tortoise.Connection, GATCore.MQTT.get_tortoise_config()}]
        false -> []
      end

    children =
      [
        {Registry, keys: :duplicate, name: Registry.ConnectionsTCP},
        {Registry, keys: :unique, name: Registry.Stations},
        {Registry, keys: :unique, name: Registry.OGNObjects},
        {GATCore.ServerTCP, []},
        {GATCore.APRSConnection, []}
      ] ++ tortoise_child

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GATCore.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
