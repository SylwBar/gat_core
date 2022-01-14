defmodule OGNCore.Packet do
  @lat_lon_scale 0x800000

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
        :full -> 0
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

  def gen_station_status(station_id, core_server_id, station_data) do
    source = [2, station_id]
    destination = 1
    type = 1
    path = [[1, core_server_id]]
    body = %{1 => station_data.rx_time, 23 => station_data.cmt}

    station_status = [source, destination, type, body, path]
    CBOR.encode(station_status)
  end

  def gen_station_position(station_id, core_server_id, position_data) do
    source = [2, station_id]
    destination = 1
    type = 2
    path = [[1, core_server_id]]
    rx_time = position_data.rx_time
    lat = round(position_data.lat * @lat_lon_scale)
    lon = round(position_data.lon * @lat_lon_scale)
    alt = position_data.alt
    body = %{1 => rx_time, 2 => [lat, lon], 3 => alt}

    station_status = [source, destination, type, body, path]
    CBOR.encode(station_status)
  end

  def gen_object_position(object_id, station_id, position_data) do
    source = [3, object_id]
    destination = 1
    type = 1
    path = [[2, station_id]]
    rx_time = position_data.rx_time
    lat = round(position_data.lat * @lat_lon_scale)
    lon = round(position_data.lon * @lat_lon_scale)
    alt = position_data.alt
    cse = position_data.cse
    spd = position_data.spd
    body = %{1 => rx_time, 2 => [lat, lon], 3 => alt, 5 => cse, 6 => spd, 23 => position_data.cmt}

    object_status = [source, destination, type, body, path]
    CBOR.encode(object_status)
  end
end
