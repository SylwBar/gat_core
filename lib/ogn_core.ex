defmodule OGNCore do
  def stations() do
    station_list =
      Registry.select(Registry.Stations, [
        {{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}
      ])

    Enum.map(station_list, fn {name, _pid, _data} -> IO.puts("#{name}") end)
    IO.puts("Number: #{length(station_list)}")
  end

  def print_station(station_id) do
    OGNCore.Station.print_state_by_id(station_id)
  end

  def objects() do
    obj_list =
      Registry.select(Registry.OGNObjects, [
        {{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}
      ])

    Enum.map(obj_list, fn {{addr_type, addr}, _pid, type} ->
      addr_str = Base.encode16(addr)

      IO.puts("(#{addr_type},#{addr_str}): #{type}")
    end)

    IO.puts("Number: #{length(obj_list)}")
  end

  def print_object(addr_type, addr_hex_str) do
    {:ok, addr_bin} = Base.decode16(addr_hex_str)
    OGNCore.OGNObject.print_state_by_id({addr_type, addr_bin})
  end

  def set_object_delay(addr_type, addr_hex_str, delay_sec) do
    {:ok, addr_bin} = Base.decode16(addr_hex_str)
    OGNCore.OGNObject.set_delay_by_id({addr_type, addr_bin}, delay_sec)
  end

  def get_object_delay(addr_type, addr_hex_str) do
    {:ok, addr_bin} = Base.decode16(addr_hex_str)
    OGNCore.OGNObject.get_delay_by_id({addr_type, addr_bin})
  end
end
