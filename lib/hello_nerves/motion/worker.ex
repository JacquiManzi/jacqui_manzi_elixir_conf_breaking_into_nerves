defmodule HelloNerves.Motion.Worker do
  use GenServer
  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, [{:working, false}, 0], name: MotionDetectionWorker)
  end

  @impl true
  def init([{:working, _working}, 0] = args) do
    {:ok, args}
  end

  @impl true
  def handle_cast({:detect_motion, image}, [{:working, working}, previous_count] = state) do

    case working do
      true ->
        {:reply, state}

      false ->
        sections = HelloNerves.Motion.MotionDetection.detect_motion(image)

        count = Enum.sum(sections)

        if count < previous_count - (previous_count * 0.20) do
          Logger.debug(inspect(count))
          Logger.info("Moving")
        end

        if count > previous_count + (previous_count * 0.20) do
          Logger.debug(inspect(count))
          Logger.info("Moving")
        end

        {:noreply, [{:working, false}, count]}
    end
  end
end
