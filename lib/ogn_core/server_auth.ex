defmodule OGNCore.ServerAuth do
  def check_auth({2, _station_id}) do
    if length(OGNCore.ServerTCP.get_connections()) < OGNCore.Config.get_core_server_max_conn() do
      :ok
    else
      :full
    end
  end

  def check_auth(_, _), do: :no_auth
end
