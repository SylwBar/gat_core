defmodule GATCore.ServerAuth do
  def check_auth({2, _station_id}) do
    if length(GATCore.ServerTCP.get_connections()) < GATCore.Config.get_core_server_max_conn() do
      :ok
    else
      :full
    end
  end

  def check_auth(_, _), do: :no_auth
end
