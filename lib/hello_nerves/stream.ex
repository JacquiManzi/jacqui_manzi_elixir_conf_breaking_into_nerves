# GenStage A - we get jpegs in and detect if there is movement
# If there is movement, let's update our state and send information downstream to the next GenStage
defmodule HelloNerves.Stream do
  use GenStage

  def start_link([] = args) do
    IO.inspect "in startlink"
    GenStage.start_link(HelloNerves.Stream, args, name: HelloNerves.Stream)
  end

  def init([] = args) do
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

  def handle_demand(_demand, state) do
    # We don't care about the demand
    {:noreply, [], state}
  end
end
