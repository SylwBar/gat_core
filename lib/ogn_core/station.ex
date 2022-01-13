defmodule OGNCore.Station do
  use GenServer
  require Logger

  # Inactivity timeout check set to 1 minute
  @inactive_check_msec 60_000
  # Inactive event after 30 minutes
  @inactive_event_time_msec 30 * 60_000
  # Process exit after 120 minutes of inactivity
  @process_exit_time_msec 120 * 60_000

  # ----- Station API -----
  def start(id) do
    reg_name = {:via, Registry, {Registry.Stations, id}}
    GenServer.start(__MODULE__, [id], name: reg_name)
  end

  def get_pid(id) do
    case Registry.lookup(Registry.Stations, id) do
      [{pid, _}] -> {:ok, pid}
      [] -> start(id)
    end
  end

  def send_aprs(pid, pkt), do: GenServer.cast(pid, {:aprs, pkt})

  defp get_state(pid), do: GenServer.call(pid, :get_state)

  defp print_state(state) do
    IO.puts("Station data for #{inspect(state.id)}:")
    last_rx_datetime = state.last_rx_time |> DateTime.from_unix!(:millisecond)
    IO.puts("Last packet receive time: #{last_rx_datetime}")
    rx_datetime = state.rx_time |> DateTime.from_unix!(:second)
    IO.puts("Received time:\t#{rx_datetime}")
    IO.puts("Latitude:\t#{state.rx_lat}")
    IO.puts("Longitude:\t#{state.rx_lon}")
    IO.puts("Altitude:\t#{state.rx_alt}")
    IO.puts("Comment:\t#{state.rx_comment}")
  end

  def print_state_by_id(id) do
    case Registry.lookup(Registry.Stations, id) do
      [{pid, _}] ->
        get_state(pid) |> print_state

      [] ->
        IO.puts("No such station.")
        :error
    end
  end

  # ----- Station callbacks -----

  @impl true
  def init([id]) do
    last_rx_time = :erlang.system_time(:millisecond)
    inactive_timer_ref = :erlang.send_after(@inactive_check_msec, self(), :inactive_check_exp)

    state = %{
      id: id,
      server_id: OGNCore.Config.get_core_server_name(),
      last_rx_time: last_rx_time,
      inactive_timer_ref: inactive_timer_ref,
      inactive_event_sent: false,
      rx_time: nil,
      rx_lat: nil,
      rx_lon: nil,
      rx_alt: nil,
      rx_comment: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:aprs, pkt}, state) do
    new_state =
      case OGNCore.APRS.get_aprs_addr(pkt) do
        {:ok, _addr_list, aprs_message} ->
          case aprs_message do
            <<"/", pos_ts::bytes>> ->
              case OGNCore.APRS.get_aprs_position_with_timestamp(pos_ts) do
                {:ok, {time, lat, lon, alt, _s1, _s2}, _comment} ->
                  rx_time = OGNCore.APRS.get_unix_time(time)
                  position_data = %{rx_time: rx_time, lat: lat, lon: lon, alt: alt}

                  position_packet =
                    OGNCore.Packet.gen_station_position(state.id, state.server_id, position_data)

                  Tortoise.publish(state.server_id, "glidernet", position_packet, qos: 0)

                  new_state = %{
                    state
                    | rx_time: rx_time,
                      rx_lat: lat,
                      rx_lon: lon,
                      rx_alt: alt
                  }

                  {:ok, new_state}

                _ ->
                  Logger.warning(
                    "OGNCore.Station #{inspect(self())} #{inspect(state.id)}: get_aprs_position_with_timestamp not recognized: #{pkt}"
                  )

                  :aprs_error
              end

            <<">", status::bytes>> ->
              case OGNCore.APRS.get_status(status) do
                {:ok, {time}, comment} ->
                  rx_time = OGNCore.APRS.get_unix_time(time)
                  status_data = %{rx_time: rx_time, cmt: comment}

                  status_packet =
                    OGNCore.Packet.gen_station_status(state.id, state.server_id, status_data)

                  Tortoise.publish(state.server_id, "glidernet", status_packet, qos: 0)

                  new_state = %{state | rx_time: rx_time, rx_comment: comment}
                  {:ok, new_state}

                _ ->
                  Logger.warning(
                    "OGNCore.Station #{inspect(self())} #{inspect(state.id)}: get_status not recognized: #{pkt}"
                  )

                  :aprs_error
              end

            _ ->
              Logger.warning(
                "OGNCore.Station #{inspect(self())} #{inspect(state.id)}: aprs_message not recognized: #{pkt}"
              )

              :aprs_error
          end

        :error ->
          Logger.warning(
            "OGNCore.Station #{inspect(self())} #{inspect(state.id)}: get_aprs_addr() failed: #{pkt}"
          )

          :aprs_error
      end

    case new_state do
      {:ok, updated_state} ->
        last_rx_time = :erlang.system_time(:millisecond)
        {:noreply, %{updated_state | last_rx_time: last_rx_time}}

      :aprs_error ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:inactive_check_exp, state) do
    if :erlang.system_time(:millisecond) - state.last_rx_time > @process_exit_time_msec do
      Logger.debug(
        "OGNCore.Station #{inspect(self())} #{inspect(state.id)}: process ended due to no inactivity."
      )

      {:stop, :normal, %{}}
    else
      inactive_event_sent =
        if :erlang.system_time(:millisecond) - state.last_rx_time > @inactive_event_time_msec do
          if state.inactive_event_sent == false do
            Logger.debug(
              "OGNCore.Station #{inspect(self())} #{inspect(state.id)}: event inactive."
            )
          end

          true
        else
          false
        end

      inactive_timer_ref = :erlang.send_after(@inactive_check_msec, self(), :inactive_check_exp)

      {:noreply,
       %{state | inactive_timer_ref: inactive_timer_ref, inactive_event_sent: inactive_event_sent}}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
end
