defmodule OGNCore.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    try do
      env = Application.fetch_env!(:ogn_core, :env)
      ver = Application.spec(:ogn_core, :vsn) |> to_string()
      Logger.info("OGN Core #{ver} #{env}")
      toml_file = Application.fetch_env!(:ogn_core, :toml_config)
      Logger.info("Reading configuration file: #{toml_file}")
      toml_config = Toml.decode_file!(toml_file)
      server_name = Map.get(toml_config, "server_name")

      if server_name == nil do
        raise "No server name provided in configuration file"
      end

      Logger.info("OGN Core server name: #{server_name}")

      children = [
        # Starts a worker by calling: OGNCore.Worker.start_link(arg)
        # {OGNCore.Worker, arg}
      ]

      # See https://hexdocs.pm/elixir/Supervisor.html
      # for other strategies and supported options
      opts = [strategy: :one_for_one, name: OGNCore.Supervisor]
      Supervisor.start_link(children, opts)
    rescue
      e in RuntimeError -> {:error, e}
      e in ArgumentError -> {:error, e}
      e in File.Error -> {:error, e}
      e in Toml.Error -> {:error, e}
    end
  end
end
