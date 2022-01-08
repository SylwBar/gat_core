defmodule OGNCore.APRS do
  import NimbleParsec

  # -------- APRS address header --------
  aprs_id = ascii_string([?A..?Z, ?a..?z, ?0..?9, ?-, ?*], min: 1)
  status = string(">")
  sep = string(",")
  msg = string(":")
  type = choice([string("qAS"), string("qAC")])

  # parse APRS address: LHSL>OGNSDR,TCPIP*,qAC,GLIDERN1:
  defparsec(
    :ps_aprs_addr,
    aprs_id
    |> ignore(status)
    |> concat(aprs_id)
    |> ignore(sep)
    |> concat(aprs_id)
    |> ignore(sep)
    |> concat(type)
    |> ignore(sep)
    |> concat(aprs_id)
    |> ignore(msg),
    debug: false
  )

  def get_aprs_addr(aprs_packet) do
    case ps_aprs_addr(aprs_packet) do
      {:ok, addr_list, rest, _context, _position, _byte_offset} ->
        {:ok, addr_list, rest}

      {:error, _reason, _rest, _context, _position, _byte_offset} ->
        :error
    end
  end

  # -------- APRS position with timestamp --------
  # "/123456h1234.56NI12345.67E&/A=123456"

  time = integer(2) |> integer(2) |> integer(2) |> ignore(string("h"))

  latitude =
    integer(2)
    |> integer(2)
    |> ignore(string("."))
    |> integer(2)
    |> choice([string("N"), string("S")])

  longitude =
    integer(3)
    |> integer(2)
    |> ignore(string("."))
    |> integer(2)
    |> choice([string("E"), string("W")])

  altitude = ignore(string("/A=")) |> integer(6)

  symbol1 = ascii_char([?I, ?/])
  symbol2 = ascii_char([?&])

  # position with timestamp
  defparsec(
    :ps_position_with_timestamp,
    time
    |> concat(latitude)
    |> concat(symbol1)
    |> concat(longitude)
    |> concat(symbol2)
    |> concat(altitude),
    debug: false
  )

  def get_aprs_position_with_timestamp(aprs_packet) do
    case ps_position_with_timestamp(aprs_packet) do
      {:ok,
       [
         h,
         m,
         s,
         lat_deg,
         lat_min,
         lat_sec,
         lat_n_s,
         s1,
         lon_deg,
         lon_min,
         lon_sec,
         lon_e_w,
         s2,
         alt
       ], rest, _context, _position, _byte_offset} ->
        time = {h, m, s}

        lat =
          case lat_n_s do
            "N" -> lat_deg + lat_min / 60 + lat_sec / 3600
            "S" -> -(lat_deg + lat_min / 60 + lat_sec / 3600)
          end

        lon =
          case lon_e_w do
            "E" -> lon_deg + lon_min / 60 + lon_sec / 3600
            "W" -> -(lon_deg + lon_min / 60 + lon_sec / 3600)
          end

        {:ok, {time, lat, lon, alt, s1, s2}, rest}

      {:error, _reason, _rest, _context, _position, _byte_offset} ->
        :error
    end
  end

  # -------- APRS status --------
  # ">123456h v0.2.6.ARM CPU:0.4 RAM:587.2/968.2MB NTP:0.2ms/-5.5ppm +34.3C 0/0Acfts[1h] RF:+110-3.7ppm/-0.37dB/+11.4dB@10km[507099]/+17.6dB@10km[68/135]"

  defparsec(
    :ps_status,
    time,
    debug: false
  )

  def get_status(aprs_packet) do
    case ps_status(aprs_packet) do
      {:ok, [h, m, s], rest, _context, _position, _byte_offset} ->
        time = {h, m, s}
        {:ok, {time}, rest}

      {:error, _reason, _rest, _context, _position, _byte_offset} ->
        :error
    end
  end

  # -------- Extracts source Core ID from APRS packet --------

  def get_source_id(aprs_packet) do
    aprs_id =
      case :binary.match(aprs_packet, ">") do
        {aprs_id_len, 1} -> :binary.part(aprs_packet, {0, aprs_id_len})
        _e -> :none
      end

    q_type =
      case :binary.matches(aprs_packet, ["qAC", "qAS"]) do
        [{q_type_pos, 3}] -> :binary.part(aprs_packet, {q_type_pos, 3})
        _e -> :none
      end

    id =
      case :binary.match(aprs_packet, " id") do
        {id_pos, 3} when id_pos + 8 + 3 <= byte_size(aprs_packet) ->
          :binary.part(aprs_packet, {id_pos + 3, 8})

        _ ->
          :none
      end

    case {q_type, aprs_id, id} do
      {"qAC", id, :none} -> {:station, id}
      _ -> :unknown
    end
  end
end
