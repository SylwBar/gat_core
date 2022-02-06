defmodule GATCore.APRSConnection do
  @reconnect_timer_msec 10_000
  @client_keep_alive_timer_msec 120_000
  @server_keep_alive_timer_msec 60_000

  use GenServer
  require Logger

  @impl true
  # ----- APRS Connection process init. function -----

  def init([]) do
    server_addr = GATCore.Config.get_aprs_server_addr()
    server_port = GATCore.Config.get_aprs_server_port()
    client_id = GATCore.Config.get_aprs_client_id()

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
        :erlang.send_after(@reconnect_timer_msec, self(), :connect)
        {:noreply, %{state | socket: nil, pkt_fragment: <<>>}}

      {:ok, {ip1, ip2, ip3, ip4} = server_ip4} ->
        Logger.info(
          "APRSConnection: connection attempt to #{state.server_addr}, IP: #{ip1}.#{ip2}.#{ip3}.#{ip4}"
        )

        socket =
          case :gen_tcp.connect(server_ip4, state.server_port, [:binary, active: true]) do
            {:ok, socket} ->
              Logger.info("APRSConnection: connected to APRS server")
              ver = Application.spec(:gat_core, :vsn) |> to_string()

              login = "user CORE-#{state.client_id} pass 25320 vers GATCore #{ver}\r\n"

              :ok = :gen_tcp.send(socket, login)

              socket

            _ ->
              Logger.error("APRSConnection: connection error")
              :erlang.send_after(@reconnect_timer_msec, self(), :connect)
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
    client_ka_timer = :erlang.send_after(@client_keep_alive_timer_msec, self(), :send_keep_alive)

    {:noreply, %{state | client_ka_timer: client_ka_timer}}
  end

  def handle_info(:send_keep_alive, state) do
    :ok = :gen_tcp.send(state.socket, "#KA\r\n")

    client_ka_timer = :erlang.send_after(@client_keep_alive_timer_msec, self(), :send_keep_alive)

    {:noreply, %{state | client_ka_timer: client_ka_timer}}
  end

  # ----- Server keep alive messages -----
  def handle_info(:restart_server_ka_timer, state) do
    if state.server_ka_timer != nil do
      :erlang.cancel_timer(state.server_ka_timer)
    end

    server_ka_timer = :erlang.send_after(@server_keep_alive_timer_msec, self(), :server_time_out)

    {:noreply, %{state | server_ka_timer: server_ka_timer}}
  end

  # ----- APRS server not sending data -----
  def handle_info(:server_time_out, state) do
    Logger.warning("APRSConnection: server timeout")
    :ok = :gen_tcp.close(state.socket)

    if state.client_ka_timer != nil do
      :timer.cancel(state.client_ka_timer)
    end

    :timer.send_after(@reconnect_timer_msec, self(), :connect)

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

    :erlang.send_after(@reconnect_timer_msec, self(), :connect)

    {:noreply,
     %{state | socket: nil, pkt_fragment: <<>>, client_ka_timer: nil, server_ka_timer: nil}}
  end

  # ----- APRS Client private functions -----
  defp handle_packet(<<"#", _::bytes>> = cmt), do: handle_comment(cmt)

  defp handle_packet(pkt) do
    case GATCore.APRS.get_source_id(pkt) do
      {:ogn_station, id} ->
        {:ok, pid} = GATCore.Station.get_pid(id)
        GATCore.Station.send_aprs(pid, pkt)

      {:ogn_object, id, type} ->
        {:ok, pid} = GATCore.OGNObject.get_pid(id, type)
        GATCore.OGNObject.send_aprs(pid, pkt)

      :unknown ->
        :ok
    end
  end

  defp handle_comment(<<"# logresp", _::bytes>> = cmt) do
    send(self(), :start_client_ka_timer)
    Logger.info("APRSConnection: #{cmt}")
  end

  defp handle_comment(<<"# aprsc", _::bytes>> = _cmt) do
    send(self(), :restart_server_ka_timer)
  end

  defp handle_comment(<<"# ognsim", _::bytes>> = _cmt) do
    send(self(), :restart_server_ka_timer)
  end

  defp handle_comment(<<"#", _::bytes>> = cmt) do
    Logger.info("APRSConnection: #{cmt}")
  end

  # ----- APRSConnection API -----
  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end
end
