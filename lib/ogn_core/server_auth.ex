defmodule OGNCore.ServerAuth do
  def check_auth({2, _station_id}), do: :ok
  def check_auth(_), do: :no_auth
end
