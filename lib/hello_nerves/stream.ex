# GenStage A - we get jpegs in and detect if there is movement
# If there is movement, let's update our state and send information downstream to the next GenStage
defmodule HelloNerves.Stream do
  use GenStage
  require Logger

  @motion_sensitivity 0.005

  def start_link() do
    GenStage.start_link(HelloNerves.Stream, [{:moving, false}, 0], name: HelloNerves.Stream)
  end

  def init([{:moving, _moving}, 0] = args) do
    {:producer, args}
  end

  @doc "Sends an event and returns only after the event is dispatched."
  def sync_notify(event, timeout \\ 0) do
    GenStage.call(__MODULE__, {:notify, event}, timeout)
  end

  def handle_call({:notify, event}, _from, state) do
    # Dispatch immediately
    {:reply, :ok, [event], state}
  end

  def handle_demand(_demand, [{:moving, _moving}, previous_count]) do
    jpeq_binary_list = Picam.next_frame() |> :binary.bin_to_list()
    count = Enum.sum(jpeq_binary_list)
    percentage = previous_count * @motion_sensitivity
    is_moving = count < previous_count - percentage or count > previous_count + percentage
    {:noreply, jpeq_binary_list, [{:moving, is_moving}, count]}
  end
end
