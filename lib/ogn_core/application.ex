defmodule OGNCore.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    env = Application.fetch_env!(:ogn_core, :env)
    ver = Application.spec(:ogn_core, :vsn) |> to_string()
    Logger.info("OGN Core #{ver} #{env}")
    toml_file = Application.fetch_env!(:ogn_core, :toml_config)
    :ok = OGNCore.Config.read_toml(toml_file)

    tortoise_child =
      case OGNCore.Config.get_mqtt_enabled() do
        true -> [{Tortoise.Connection, OGNCore.MQTT.get_tortoise_config()}]
        false -> []
      end

    children =
      [
        {OGNCore.ServerTCP, []},
        {Registry, keys: :duplicate, name: Registry.ConnectionsTCP},
        {OGNCore.APRSConnection, []}
      ] ++ tortoise_child

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: OGNCore.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
