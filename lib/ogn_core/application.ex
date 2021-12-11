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

    children = [
      # Starts a worker by calling: OGNCore.Worker.start_link(arg)
      # {OGNCore.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: OGNCore.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
