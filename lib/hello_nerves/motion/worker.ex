defmodule HelloNerves.Motion.Worker do
  use GenServer
  require Logger

  @motion_sensitivity 0.005

  def start_link() do
    GenServer.start_link(__MODULE__, [{:moving, false}, 0], name: MotionDetectionWorker)
  end

  @impl true
  def init([{:moving, _moving}, 0] = args) do
    Logger.info("in worker")
    spawn_port()
    {:ok, stream} =
      GenStage.start_link(HelloNerves.Stream, 0, name: HelloNerves.Stream)

    {:ok, recorder} =
      recorder = GenStage.start_link(HelloNerves.Recorder, [], name: HelloNerves.Recorder)

    GenStage.sync_subscribe(recorder, to: stream, max_demand: 10, min_demand: 0)

    {:ok, args}
  end

  def handle_info(:reconnect_port, state) do
    with port when is_port(port) <- spawn_port() do
      {:noreply, state}
    else
      _ ->
        Process.send_after(self(), :reconnect_port, 10_000)
        {:noreply, state}
    end
  end

  def handle_info({_, {:exit_status, _}}, state) do
    Process.send_after(self(), :reconnect_port, 10_000)
    {:noreply, state}
  end

  defp spawn_port() do
    executable = Path.join(:code.priv_dir(:picam), "raspijpgs")
    Port.open({:spawn_executable, executable}, [{:packet, 4}, :use_stdio, :binary, :exit_status])
  end

  def handle_info({_, {:data, jpg}}, state) do
    Logger.info("YES!!")
    {:noreply, state}
  end

  @impl true
  def handle_cast({:detect_motion, image}, [{:moving, moving}, previous_count] = _state) do
    jpeq_binary_list = HelloNerves.Motion.MotionDetection.detect_motion(image)
    count = Enum.sum(jpeq_binary_list)
    percentage = previous_count * @motion_sensitivity
    is_moving = count < previous_count - percentage or count > previous_count + percentage

    {:noreply, [{:moving, is_moving}, count]}
  end
end
