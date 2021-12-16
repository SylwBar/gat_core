defmodule APRSConnection do
  @reconnect_timer_sec 10
  @client_keep_alive_timer_sec 120
  @server_keep_alive_timer_sec 60

  use GenServer
  require Logger

  @impl true
  # ----- APRS Connection process init. function -----

  def init([aprs_config]) do
    server_addr = Map.get(aprs_config, "server_addr")
    server_port = Map.get(aprs_config, "server_port")
    client_id = Map.get(aprs_config, "client_id")

    state = %{
      server_addr: server_addr,
      server_port: server_port,
      client_id: client_id,
      socket: nil,
      client_ka_timer: nil,
      server_ka_timer: nil,
      pkt_fragment: <<>>
    }

    send(self(), :connect)
    {:ok, state}
  end

  @impl true
  # ----- APRS connection attempt -----
  def handle_info(:connect, state) do
    case state.server_addr |> String.to_charlist() |> :inet.getaddr(:inet) do
      {:error, error} ->
        Logger.error("APRSConnection: address error: #{inspect(error)}")
        :erlang.send_after(@reconnect_timer_sec * 1000, self(), :connect)
        {:noreply, %{state | socket: nil, pkt_fragment: <<>>}}

      {:ok, {ip1, ip2, ip3, ip4} = server_ip4} ->
        Logger.info(
          "APRSConnection: connection attempt to #{state.server_addr}, IP: #{ip1}.#{ip2}.#{ip3}.#{ip4}"
        )

        socket =
          case :gen_tcp.connect(server_ip4, state.server_port, [:binary, active: true]) do
            {:ok, socket} ->
              Logger.info("APRSConnection: connected to APRS server")
              ver = Application.spec(:ogn_core, :vsn) |> to_string()

              login = "user CORE-#{state.client_id} pass 25320 vers OGNCore #{ver}\r\n"

              :ok = :gen_tcp.send(socket, login)

              socket

            _ ->
              Logger.error("APRSConnection: connection error")
              :erlang.send_after(@reconnect_timer_sec * 1000, self(), :connect)
              nil
          end

        {:noreply, %{state | socket: socket, pkt_fragment: <<>>}}
    end
  end

  # ----- TCP data received -----
  def handle_info({:tcp, _socket, packet}, state) do
    packet_list =
      <<state.pkt_fragment::binary, packet::binary>>
      |> :binary.split("\r\n", [:global])

    {completed_packet_list, [pkt_fragment]} = :lists.split(length(packet_list) - 1, packet_list)

    # Handle APRS packets
    :lists.map(&handle_packet(&1), completed_packet_list)
    {:noreply, %{state | pkt_fragment: pkt_fragment}}
  end

  # ----- Client keep alive messages -----
  def handle_info(:start_client_ka_timer, state) do
    client_ka_timer =
      :erlang.send_after(@client_keep_alive_timer_sec * 1000, self(), :send_keep_alive)

    {:noreply, %{state | client_ka_timer: client_ka_timer}}
  end

  def handle_info(:send_keep_alive, state) do
    :ok = :gen_tcp.send(state.socket, "#KA\r\n")

    client_ka_timer =
      :erlang.send_after(@client_keep_alive_timer_sec * 1000, self(), :send_keep_alive)

    {:noreply, %{state | client_ka_timer: client_ka_timer}}
  end

  # ----- Server keep alive messages -----
  def handle_info(:restart_server_ka_timer, state) do
    if state.server_ka_timer != nil do
      :erlang.cancel_timer(state.server_ka_timer)
    end

    server_ka_timer =
      :erlang.send_after(@server_keep_alive_timer_sec * 1000, self(), :server_time_out)

    {:noreply, %{state | server_ka_timer: server_ka_timer}}
  end

  # ----- APRS server not sending data -----
  def handle_info(:server_time_out, state) do
    Logger.warning("APRSConnection: server timeout")
    :gen_tcp.close(state.socket)

    if state.client_ka_timer != nil do
      :timer.cancel(state.client_ka_timer)
    end

    :timer.send_after(@reconnect_timer_sec * 1000, self(), :connect)

    {:noreply,
     %{state | socket: nil, pkt_fragment: <<>>, client_ka_timer: nil, server_ka_timer: nil}}
  end

  # ----- TCP connection down -----
  def handle_info({:tcp_closed, _socket}, state) do
    Logger.warning("APRSConnection: connection closed")

    if state.client_ka_timer != nil do
      :erlang.cancel_timer(state.client_ka_timer)
    end

    if state.server_ka_timer != nil do
      :erlang.cancel_timer(state.server_ka_timer)
    end

    :erlang.send_after(@reconnect_timer_sec * 1000, self(), :connect)

    {:noreply,
     %{state | socket: nil, pkt_fragment: <<>>, client_ka_timer: nil, server_ka_timer: nil}}
  end

  # ----- APRS Client private functions -----
  defp handle_packet(<<"#", _::bytes>> = cmt), do: handle_comment(cmt)
  defp handle_packet(_), do: :ok

  defp handle_comment(<<"# logresp", _::bytes>> = cmt) do
    send(self(), :start_client_ka_timer)
    Logger.info("APRSConnection: #{cmt}")
  end

  defp handle_comment(<<"# aprsc", _::bytes>> = cmt) do
    send(self(), :restart_server_ka_timer)
    Logger.debug("APRSConnection: #{cmt}")
  end

  defp handle_comment(<<"#", _::bytes>> = cmt) do
    Logger.info("APRSConnection: #{cmt}")
  end

  # ----- APRSConnection API -----
  def start_link([aprs_config]) do
    GenServer.start_link(APRSConnection, [aprs_config], name: __MODULE__)
  end
end
