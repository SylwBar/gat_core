defmodule OGNCore.MQTT do
  def get_tortoise_config() do
    client_id = OGNCore.Config.get_core_server_name()
    user_name = OGNCore.Config.get_mqtt_user_name()
    password = OGNCore.Config.get_mqtt_password()
    host = OGNCore.Config.get_mqtt_server_addr()
    port = OGNCore.Config.get_mqtt_server_port()

    [
      client_id: client_id,
      user_name: user_name,
      password: password,
      server: {Tortoise.Transport.Tcp, host: host, port: port},
      handler: {Tortoise.Handler.Logger, []}
    ]
  end
end
