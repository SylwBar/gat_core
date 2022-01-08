defmodule OGNCore do
  def stations_list() do
    Registry.select(Registry.Stations, [
      {{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}
    ])
  end

  def ogn_objects_list() do
    Registry.select(Registry.OGNObjects, [
      {{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}
    ])
  end
end
