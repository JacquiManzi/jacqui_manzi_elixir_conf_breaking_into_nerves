defmodule NightVision.Motion.Worker do
  use GenServer
  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, [{:working, false}, []], name: MotionDetectionWorker)
  end

  @impl true
  def init([{:working, _working}, []] = args) do
    {:ok, args}
  end

  @impl true
  def handle_cast({:detect_motion, image}, [{:working, working}, _sections] = state) do
    Logger.info("got here")

    case working do
      true ->
        {:reply, state}

      false ->
        sections = NightVision.Motion.MotionDetection.detect_motion(image)
        Logger.info(sections)
        {:reply, [{:working, false}, sections]}
    end
  end
end
