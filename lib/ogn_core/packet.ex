defmodule OGNCore.Packet do
  def gen_core_keep_alive() do
    source = 0
    destination = 0
    type = 0
    body = %{}
    path = []

    keep_alive = [source, destination, type, body, path]
    CBOR.encode(keep_alive)
  end

  def gen_core_login_reply(server_name, reply) do
    reply_id =
      case reply do
        :ok -> 1
        :no_auth -> 2
      end

    server_id = [1, server_name]
    msg_body = %{1 => server_id, 2 => reply_id}

    source = 0
    destination = 0
    type = 2
    body = msg_body
    path = []

    core_login_reply = [source, destination, type, body, path]
    CBOR.encode(core_login_reply)
  end
end
