defmodule APRSConnection do
  @reconnect_timer_sec 10
  @keep_alive_timer_sec 60

  use GenServer
  require Logger

  @impl true
  def init([aprs_config, core_server_name]) do
    server_addr = Map.get(aprs_config, "server_addr")
    server_port = Map.get(aprs_config, "server_port")
    client_id = Map.get(aprs_config, "client_id")

    state = %{
      server_addr: server_addr,
      server_port: server_port,
      client_id: client_id,
      core_server_name: core_server_name,
      socket: nil,
      pkt_fragment: <<>>,
      ka_timer: nil
    }

    send(self(), :connect)
    {:ok, state}
  end

  @impl true
  def handle_info(:connect, state) do
    Logger.info("APRSConnection: connection attempt")
    {:ok, server_ip4} = state.server_addr |> String.to_charlist() |> :inet.getaddr(:inet)

    {socket, ka_timer} =
      case :gen_tcp.connect(server_ip4, state.server_port, [:binary, active: true]) do
        {:ok, socket} ->
          Logger.info("APRSConnection: connected to APRS server")
          ver = Application.spec(:ogn_core, :vsn) |> to_string()

          login =
            "user CORE-#{state.client_id} pass 25320 vers Core-#{state.core_server_name} #{ver}\r\n"

          :ok = :gen_tcp.send(socket, login)
          {:ok, ka_timer} = :timer.send_interval(@keep_alive_timer_sec * 1000, :send_keep_alive)
          {socket, ka_timer}

        _ ->
          Logger.error("APRSConnection: connection error")
          :timer.send_after(@reconnect_timer_sec * 1000, :connect)
          {nil, nil}
      end

    {:noreply, %{state | socket: socket, pkt_fragment: <<>>, ka_timer: ka_timer}}
  end

  def handle_info(:send_keep_alive, state) do
    :ok = :gen_tcp.send(state.socket, "#KA\r\n")
    {:noreply, state}
  end

  def handle_info({:tcp, _socket, packet}, state) do
    packet_list =
      <<state.pkt_fragment::binary, packet::binary>>
      |> :binary.split("\r\n", [:global])

    {completed_packet_list, [pkt_fragment]} = :lists.split(length(packet_list) - 1, packet_list)

    # Handle APRS packets
    :lists.map(&handle_packet(&1), completed_packet_list)
    {:noreply, %{state | pkt_fragment: pkt_fragment}}
  end

  def handle_info({:tcp_closed, _socket}, state) do
    Logger.warning("APRSConnection: connection closed")
    if (state.ka_timer != nil) do
      :timer.cancel(state.ka_timer)
    end
    :timer.send_after(@reconnect_timer_sec * 1000, :connect)
    {:noreply, %{state | socket: nil, ka_timer: nil}}
  end

  defp handle_packet(<<"#", comment::binary>>), do: Logger.debug("APRSConnection: ##{comment}")
  defp handle_packet(_), do: :ok

  # ----- APRSConnection API -----
  def start_link([aprs_config, core_server_name]) do
    GenServer.start_link(APRSConnection, [aprs_config, core_server_name], name: __MODULE__)
  end
end
