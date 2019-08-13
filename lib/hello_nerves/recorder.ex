# GenStage B - Get's jpegs from GenStage A, which means there is movement
# This starts a stream and sends to Mux
defmodule HelloNerves.Recorder do
  use GenStage

  def start_link([] = args) do
    GenStage.start_link(HelloNerves.Recorder, args, name: HelloNerves.Recorder)
  end

  def init([] = args) do
    {:consumer, :ok, subscribe_to: [HelloNerves.Stream]}
  end

  def handle_events(events, _from, state) do
    for event <- events do
      IO.inspect({self(), event})
    end

    {:noreply, [], state}
  end
end
