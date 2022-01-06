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
      last_rx_time: last_rx_time,
      inactive_timer_ref: inactive_timer_ref,
      inactive_event_sent: false
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:aprs, _pkt}, state) do
    last_rx_time = :erlang.system_time(:millisecond)
    {:noreply, %{state | last_rx_time: last_rx_time}}
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
