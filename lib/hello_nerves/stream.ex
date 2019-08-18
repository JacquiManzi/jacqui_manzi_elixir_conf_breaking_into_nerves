# GenStage A - we get jpegs in and detect if there is movement
# If there is movement, let's update our state and send information downstream to the next GenStage
defmodule HelloNerves.Stream do
  use GenStage
  require Logger

  @motion_sensitivity 0.005

  def start_link(_args) do
    GenStage.start_link(HelloNerves.Stream, [], name: HelloNerves.Stream)
  end

  def init(_args) do
    {:producer, []}
  end

  @doc "Sends an event and returns only after the event is dispatched."
  def sync_notify(event, timeout \\ 0) do
    GenStage.call(__MODULE__, {:notify, event}, timeout)
  end

  def handle_call({:notify, event}, _from, state) do
    # Dispatch immediately
    {:reply, :ok, [event], state}
  end

  def handle_demand(_demand, state) do
    IO.inspect "in demand"
    Logger.info("in demand")
    IO.inspect state
    Logger.debug(inspect(state))
    list = state ++ [Picam.next_frame()]
#    jpe_binary_list = jpg |> :binary.bin_to_list()
#    sum = Enum.sum(jpe_binary_list)
#    percentage = previous_sum * @motion_sensitivity
#    is_moving = sum < previous_sum - percentage or sum > previous_sum + percentage

    {:noreply, list, list}
  end
end
