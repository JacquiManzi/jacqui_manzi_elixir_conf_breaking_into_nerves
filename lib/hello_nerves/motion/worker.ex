defmodule HelloNerves.Motion.Worker do
  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: MotionDetectionWorker)
  end

  @impl true
  def init(_opts) do
    File.mkdir("/tmp/frames")
    port = spawn_frame_port()
    Process.send_after(self(), :start_genstages, 10000)

    {:ok, %{port: port}}
  end

  @impl true
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
    Logger.info("we're spawning a new port...")

    with port when is_port(port) <- spawn_frame_port() do
      {:noreply, state}
    else
      _ ->
        Process.send_after(self(), :reconnect_port, 10_000)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({_, {:exit_status, status}}, state) do
    Logger.info("got exit status")
    Logger.debug(inspect(status))
#    if status != 1, do: Process.send_after(self(), :reconnect_port, 10_000)
    {:noreply, state}
  end

  @impl true
  def handle_info({port, {:data, text_line}}, state) do
    #    Logger.info("Latest output: #{text_line}")
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:motion_detected, _}, %{port: port}) do
    Logger.info("attempting to close frame port")
    {:os_pid, pid} = Port.info(port, :os_pid)
    System.cmd("kill", ["-KILL", "#{pid}"])
    rtmp_port = spawn_rtmp_port()
    {:noreply, %{port: rtmp_port}}
  end

  @impl true
  def handle_cast({:motion_undetected, _}, %{port: port}) do
    Logger.info("attempting to close rtmp port")
    {:os_pid, pid} = Port.info(port, :os_pid)
    System.cmd("kill", ["-KILL", "#{pid}"])
    frame_port = spawn_frame_port()
    {:noreply, %{port: frame_port}}
  end

  defp spawn_frame_port() do
    Logger.info("attempting to open frame")
    executable = System.find_executable("ffmpeg")

    port =
      Port.open({:spawn_executable, executable}, [
        :stderr_to_stdout,
        :use_stdio,
        :exit_status,
        :binary,
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
           "-r",
           "10",
           "/tmp/frames/foo-%03d.jpeg"
         ]}
      ])
  end

  defp spawn_rtmp_port() do
    Logger.info("attempting to open rtmp port")
    executable = System.find_executable("ffmpeg")

    port =
      Port.open({:spawn_executable, executable}, [
        :stderr_to_stdout,
        :use_stdio,
        :exit_status,
        :binary,
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
           "-b:a",
           "64k",
           "-c:v",
           "libx264",
           "-preset",
           "ultrafast",
           "-pix_fmt",
           "yuv420p",
           "-b:v",
           "3000k",
           "-g",
           "50",
           "-refs",
           "3",
           "-bf",
           "0",
           "-an",
           "-f",
           "flv",
           "#{Application.get_env(:mux, :stream_url)}/#{Application.get_env(:mux, :stream_key)}",
           "-r",
           "10",
           "/tmp/frames/foo-%03d.jpeg"
         ]}
      ])
  end
end
