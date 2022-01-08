defmodule OGNCore.OGNObject do
  use GenServer
  require Logger

  # Inactivity timeout check set to 1 minute
  @inactive_check_msec 60_000
  # Inactive event after 5 minutes
  @inactive_event_time_msec 5 * 60_000
  # Process exit after 120 minutes of inactivity
  @process_exit_time_msec 120 * 60_000

  # ----- OGNObject API -----
  def start(id, type) do
    reg_name = {:via, Registry, {Registry.OGNObjects, id, type}}
    GenServer.start(__MODULE__, [id, type], name: reg_name)
  end

  def get_pid(id, type) do
    case Registry.lookup(Registry.OGNObjects, id) do
      [{pid, _}] -> {:ok, pid}
      [] -> start(id, type)
    end
  end

  def send_aprs(pid, pkt), do: GenServer.cast(pid, {:aprs, pkt})

  defp get_state(pid), do: GenServer.call(pid, :get_state)

  defp print_state(state) do
    IO.puts("OGNObject data for #{inspect(state.id)}:")
    last_rx_datetime = state.last_rx_time |> DateTime.from_unix!(:millisecond)
    IO.puts("Last packet receive time: #{last_rx_datetime}")
    IO.puts("Type:   \t#{state.type}")
    IO.puts("Received time:\t#{inspect(state.rx_time)}")
    IO.puts("Latitude:\t#{state.rx_lat}")
    IO.puts("Longitude:\t#{state.rx_lon}")
    IO.puts("Altitude:\t#{state.rx_alt}")
    IO.puts("Course:  \t#{state.rx_cse}")
    IO.puts("Speed:  \t#{state.rx_spd}")
    IO.puts("Comment:\t#{state.rx_comment}")
    IO.puts("Path:   \t#{inspect(state.path)}")
  end

  def print_state_by_id(id) do
    case Registry.lookup(Registry.OGNObjects, id) do
      [{pid, _}] ->
        get_state(pid) |> print_state

      [] ->
        IO.puts("No such object.")
        :error
    end
  end

  # ----- OGNObject callbacks -----

  @impl true
  def init([id, type]) do
    last_rx_time = :erlang.system_time(:millisecond)
    inactive_timer_ref = :erlang.send_after(@inactive_check_msec, self(), :inactive_check_exp)

    state = %{
      id: id,
      type: type,
      last_rx_time: last_rx_time,
      inactive_timer_ref: inactive_timer_ref,
      inactive_event_sent: false,
      rx_time: nil,
      rx_lat: nil,
      rx_lon: nil,
      rx_alt: nil,
      rx_cse: nil,
      rx_spd: nil,
      rx_comment: nil,
      path: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:aprs, pkt}, state) do
    new_state =
      case OGNCore.APRS.get_aprs_addr(pkt) do
        {:ok, addr_list, aprs_message} ->
          case aprs_message do
            <<"/", pos_ts::bytes>> ->
              case OGNCore.APRS.get_pos_w_timest_cse_spd(pos_ts) do
                {:ok, {time, lat, lon, alt, cse, spd, _s1, _s2}, comment} ->
                  {:ok,
                   %{
                     state
                     | rx_time: time,
                       rx_lat: lat,
                       rx_lon: lon,
                       rx_alt: alt,
                       rx_cse: cse,
                       rx_spd: spd,
                       rx_comment: comment,
                       path: [{2, List.last(addr_list)}]
                   }}

                _ ->
                  Logger.warning(
                    "OGNCore.OGNObject #{inspect(self())} #{inspect(state.id)}: get_pos_w_timest_cse_spd not recognized: #{pkt}"
                  )

                  :aprs_error
              end

            _ ->
              Logger.warning(
                "OGNCore.OGNObject #{inspect(self())} #{inspect(state.id)}: aprs_message not recognized: #{pkt}"
              )

              :aprs_error
          end

        :error ->
          Logger.warning(
            "OGNCore.OGNObject #{inspect(self())} #{inspect(state.id)}: get_aprs_addr() failed: #{pkt}"
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
        "OGNCore.OGNObject #{inspect(self())} #{inspect(state.id)}: process ended due to no inactivity."
      )

      {:stop, :normal, %{}}
    else
      inactive_event_sent =
        if :erlang.system_time(:millisecond) - state.last_rx_time > @inactive_event_time_msec do
          if state.inactive_event_sent == false do
            Logger.debug(
              "OGNCore.OGNObject #{inspect(self())} #{inspect(state.id)}: event inactive."
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
