defmodule OGNCore.ServerAuth do
  def check_auth({2, _station_id}, server_max_conn) do
    if length(OGNCore.ServerTCP.get_connections()) < server_max_conn do
      :ok
    else
      :full
    end
  end

  def check_auth(_, _), do: :no_auth
end
