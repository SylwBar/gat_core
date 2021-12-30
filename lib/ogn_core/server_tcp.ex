defmodule OGNCore.ServerTCP do
  @login_timeout_ms 10_000
  use GenServer
  require Logger

  # ----- ServerTCP API -----
  def start_link([core_config]) do
    GenServer.start_link(__MODULE__, [core_config], name: __MODULE__)
  end

  def get_connections() do
    Registry.select(Registry.ConnectionsTCP, [
      {{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}
    ])
  end

  # ----- ServerTCP callbacks -----

  # ----- ServerTCP process init. function -----
  @impl true
  def init([core_config]) do
    server_port = Map.get(core_config, "server_port")
    server_name = Map.get(core_config, "server_name")
    server_max_conn = Map.get(core_config, "server_max_conn", 500)
    {:ok, listen_socket} = :gen_tcp.listen(server_port, [:binary, active: false, packet: 2])
    spawn(fn -> acceptor(listen_socket, server_name, server_max_conn) end)
    state = %{server_port: server_port, listen_socket: listen_socket}

    {:ok, state}
  end

  # ----- private functions -----
  defp acceptor(listen_socket, server_name, server_max_conn) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, socket} ->
        spawn(fn -> acceptor(listen_socket, server_name, server_max_conn) end)
        handle(socket, server_name, server_max_conn)

      error ->
        Logger.error("OGNCore.ServerTCP/acceptor: #{inspect(error)}")
    end
  end

  defp handle(socket, server_name, server_max_conn) do
    case :gen_tcp.recv(socket, 0, @login_timeout_ms) do
      {:ok, data} ->
        case CBOR.decode(data) do
          # Valid handle_login_request message: local link, with msg_body map
          {:ok, [0, 0, 1, msg_body, []], <<>>} when is_map(msg_body) ->
            handle_login_request(msg_body, socket, server_name, server_max_conn)

          error ->
            Logger.debug("OGNCore.ServerTCP/handle: CBOR error #{inspect(error)}")
            :error
        end

      {:error, error} ->
        Logger.debug("OGNCore.ServerTCP/handle: receive error #{inspect(error)}")
        :error
    end
  end

  # msg-type 0/1 : login request
  defp handle_login_request(msg_body, socket, server_name, server_max_conn) do
    object_id = Map.get(msg_body, 1)

    if object_id == nil do
      Logger.debug("OGNCore.ServerTCP/handle_cbor: no object_id (1)")
    else
      tuple_id = :erlang.list_to_tuple(object_id)

      case OGNCore.ServerAuth.check_auth(tuple_id, server_max_conn) do
        :ok ->
          Logger.info("OGNCore.ServerTCP accepted login: #{inspect(tuple_id)}")

          case Registry.lookup(Registry.ConnectionsTCP, tuple_id) do
            [] ->
              :ok

            [{existing_conn_pid, _}] ->
              OGNCore.ConnectionTCP.disconnect(existing_conn_pid)
          end

          {:ok, connection_pid} = OGNCore.ConnectionTCP.start(tuple_id, socket)
          reply_packet = OGNCore.Packet.gen_core_login_reply(server_name, :ok)
          :gen_tcp.send(socket, reply_packet)
          :ok = :gen_tcp.controlling_process(socket, connection_pid)

        :full ->
          Logger.info("OGNCore.ServerTCP full login: #{inspect(tuple_id)}")
          reply_packet = OGNCore.Packet.gen_core_login_reply(server_name, :full)
          :gen_tcp.send(socket, reply_packet)
          :full

        :no_auth ->
          Logger.info("OGNCore.ServerTCP no_auth login: #{inspect(tuple_id)}")
          reply_packet = OGNCore.Packet.gen_core_login_reply(server_name, :no_auth)
          :gen_tcp.send(socket, reply_packet)
          :no_auth
      end
    end
  end
end
