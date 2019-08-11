defmodule HelloNerves.Motion.Worker do
  use GenServer
  require Logger

  @motion_sensitivity 0.005

  def start_link() do
    GenServer.start_link(__MODULE__, [{:moving, false}, 0], name: MotionDetectionWorker)
  end

  @impl true
  def init([{:moving, _moving}, 0] = args), do: {:ok, args}

  @impl true
  def handle_cast({:detect_motion, image}, [{:moving, moving}, previous_count] = _state) do
    jpeq_binary_list = HelloNerves.Motion.MotionDetection.detect_motion(image)
    count = Enum.sum(jpeq_binary_list)
    percentage = previous_count * @motion_sensitivity
    is_moving = count < previous_count - percentage or count > previous_count + percentage

    {:noreply, [{:moving, is_moving}, count]}
  end
end
