defmodule HelloNerves.Motion.Worker do
  use GenServer
  require Logger

  @motion_sensitivity 0.005

  def start_link() do
    GenServer.start_link(__MODULE__, [{:moving, false}, 0, []], name: MotionDetectionWorker)
  end

  @impl true
  def init([{:moving, _moving}, 0, []] = args) do
    System.cmd("sh", ["-c", "ffmpeg -f video4linux2 -framerate 30 -input_format nv12 -video_size 640x480 -i /dev/video0 -c:v libx264 -preset ultrafast -pix_fmt yuv420p -b:v 3000k -g 30 -refs 3 -bf 0 -an -f flv rtmp://live.mux.com/app/e273881e-ba21-b44d-2033-4aeaa14f1416 /tmp/foo-%03d.jpeg "], stderr_to_stdout: true)
    {:ok, stream} = GenStage.start_link(HelloNerves.Stream, 0, name: HelloNerves.Stream)

    {:ok, recorder} =
      recorder = GenStage.start_link(HelloNerves.Recorder, [], name: HelloNerves.Recorder)

    GenStage.sync_subscribe(recorder, to: stream, timeout: 20_000)

    {:ok, args}
  end

  @impl true
  def handle_info(:reconnect_port, state) do
    with port when is_port(port) <- spawn_port() do
      {:noreply, state}
    else
      _ ->
        Process.send_after(self(), :reconnect_port, 10_000)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({_, {:exit_status, _}}, state) do
    Process.send_after(self(), :reconnect_port, 10_000)
    {:noreply, state}
  end

  @impl true
  def handle_info({_, {:data, jpg}}, [{:moving, false}, 0, buffer] = state) do
    if length(buffer) >= 200 do
      {:noreply, [{:moving, false}, 0, [jpg]]}
    else
      {:noreply, [{:moving, false}, 0, buffer ++ [jpg]]}
    end
  end

  @impl true
  def handle_cast({:detect_motion, image}, [{:moving, moving}, previous_count, _buffer] = _state) do
    jpeq_binary_list = HelloNerves.Motion.MotionDetection.detect_motion(image)
    count = Enum.sum(jpeq_binary_list)
    percentage = previous_count * @motion_sensitivity
    is_moving = count < previous_count - percentage or count > previous_count + percentage

    {:noreply, [{:moving, is_moving}, count]}
  end

  defp spawn_port() do
    executable = Path.join(:code.priv_dir(:picam), "raspijpgs")
    Port.open({:spawn_executable, executable}, [{:packet, 4}, :use_stdio, :binary, :exit_status])
  end
end
