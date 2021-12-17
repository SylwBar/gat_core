defmodule OGNCore.ServerTCP do
  use GenServer
  require Logger

  @impl true
  # ----- ServerTCP process init. function -----

  def init([_core_config]) do
    state = %{}

    {:ok, state}
  end

  # ----- ServerTCP API -----
  def start_link([core_config]) do
    GenServer.start_link(__MODULE__, [core_config], name: __MODULE__)
  end
end
