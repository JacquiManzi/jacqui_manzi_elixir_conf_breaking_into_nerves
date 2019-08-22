defmodule HelloNerves.Motion.Worker do
  use GenServer
  require Logger

  @motion_sensitivity 0.005

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: MotionDetectionWorker)
  end

  @impl true
  def init(_opts) do
    File.mkdir("/tmp/frames")
    port = spawn_port()
    Process.send_after(self(), :start_genstages, 10000)

    {:ok, %{moving: false, port: port, previous_count: 0}}
  end

  def handle_info(:start_genstages, state) do
    {:ok, stream} = GenStage.start_link(HelloNerves.Stream, [], name: HelloNerves.Stream)

    {:ok, recorder} =
      GenStage.start_link(
        HelloNerves.Recorder,
        [],
        name: HelloNerves.Recorder
      )

    GenStage.sync_subscribe(recorder, to: stream, max_demand: 30)
    {:noreply, state}
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

  defp spawn_port() do
    executable = System.find_executable("ffmpeg")

    Port.open({:spawn_executable, executable}, [
      {:args,
       [
         "-f",
         "video4linux2",
         "-framerate",
         "30",
         "-input_format",
         "nv12",
         "-video_size",
         "640x480",
         "-i",
         "/dev/video0",
         "-c:v",
         "libx264",
         "-preset",
         "ultrafast",
         "-pix_fmt",
         "yuv420p",
         "-b:v",
         "3000k",
         "-g",
         "30",
         "-refs",
         "3",
         "-bf",
         "0",
         "-an",
         "-f",
         "flv",
         "rtmp://live.mux.com/app/f312ac2b-2507-c5a6-3b20-e00f0c7f2516",
         "-r",
         "10",
         "/tmp/frames/foo-%03d.jpeg"
       ]},
      {:packet, 4},
      :use_stdio,
      :binary,
      :exit_status,
      :stderr_to_stdout
    ])
  end
end
