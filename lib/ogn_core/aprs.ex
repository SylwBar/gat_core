defmodule OGNCore.APRS do
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
