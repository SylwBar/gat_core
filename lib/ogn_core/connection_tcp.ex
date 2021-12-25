defmodule OGNCore.ConnectionTCP do
  @server_ka_timer_msec 20_000
  @client_ka_timer_msec 60_000

  use GenServer
  require Logger

  # ----- ConnectionTCP API -----
  def start(object_id, socket) do
    GenServer.start(__MODULE__, [object_id, socket])
  end

  def disconnect(pid) do
    GenServer.cast(pid, :disconnect)
  end

  # ----- ConnectionTCP callbacks -----
  @impl true
  def init([object_id, socket]) do
    :ok = :inet.setopts(socket, active: true)
    {:ok, {{ip1, ip2, ip3, ip4}, port}} = :inet.peername(socket)
    peer_str = "#{ip1}.#{ip2}.#{ip3}.#{ip4}:#{port}"
    {:ok, _} = Registry.register(Registry.ConnectionTCP, object_id, peer_str)
    Logger.info("ConnectionTCP: started for #{inspect(object_id)}")
    server_ka_timer_ref = :erlang.send_after(@server_ka_timer_msec, self(), :server_ka_timer_exp)
    client_ka_timer_ref = :erlang.send_after(@client_ka_timer_msec, self(), :client_ka_timer_exp)
    last_rx_time = :erlang.system_time(:millisecond)

    state = %{
      object_id: object_id,
      socket: socket,
      server_ka_timer_ref: server_ka_timer_ref,
      client_ka_timer_ref: client_ka_timer_ref,
      last_rx_time: last_rx_time
    }

    {:ok, state}
  end

  @impl true
  def handle_cast(:disconnect, state) do
    Logger.info("ConnectionTCP #{inspect(self())} (#{inspect(state.object_id)}) got :disconnect")
    :gen_tcp.close(state.socket)
    {:stop, :normal, %{}}
  end

  @impl true
  def handle_info({:tcp, _port, packet}, state) do
    {:ok, cbor, <<>>} = CBOR.decode(packet)
    last_rx_time = :erlang.system_time(:millisecond)

    case cbor do
      # Client KA message received
      [0, 0, 0, _, _] -> :ok
      pkt -> Logger.warning("Not recognized CBOR received #{inspect(pkt)}")
    end

    {:noreply, %{state | last_rx_time: last_rx_time}}
  end

  def handle_info(:server_ka_timer_exp, state) do
    ka_pkt = OGNCore.Packet.gen_core_keep_alive()
    :ok = :gen_tcp.send(state.socket, ka_pkt)
    server_ka_timer_ref = :erlang.send_after(@server_ka_timer_msec, self(), :server_ka_timer_exp)
    {:noreply, %{state | server_ka_timer_ref: server_ka_timer_ref}}
  end

  def handle_info(:client_ka_timer_exp, state) do
    if :erlang.system_time(:millisecond) - state.last_rx_time > @client_ka_timer_msec do
      Logger.info(
        "ConnectionTCP #{inspect(self())} (#{inspect(state.object_id)}) client timeout, disconnecting."
      )

      :gen_tcp.close(state.socket)
      {:stop, :normal, %{}}
    else
      client_ka_timer_ref =
        :erlang.send_after(@client_ka_timer_msec, self(), :client_ka_timer_exp)

      {:noreply, %{state | client_ka_timer_ref: client_ka_timer_ref}}
    end
  end

  def handle_info({:tcp_closed, _port}, state) do
    Logger.info("ConnectionTCP #{inspect(self())} (#{inspect(state.object_id)}) got :tcp_closed")
    {:stop, :normal, %{}}
  end
end
