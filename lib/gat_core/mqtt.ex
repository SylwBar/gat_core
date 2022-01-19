defmodule GATCore.MQTT do
  def get_tortoise_config() do
    client_id = GATCore.Config.get_core_server_name()
    user_name = GATCore.Config.get_mqtt_user_name()
    password = GATCore.Config.get_mqtt_password()
    host = GATCore.Config.get_mqtt_server_addr()
    port = GATCore.Config.get_mqtt_server_port()

    [
      client_id: client_id,
      user_name: user_name,
      password: password,
      server: {Tortoise.Transport.Tcp, host: host, port: port},
      handler: {Tortoise.Handler.Logger, []}
    ]
  end
end
