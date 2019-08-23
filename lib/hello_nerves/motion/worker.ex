defmodule HelloNerves.Motion.Worker do
  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: MotionDetectionWorker)
  end

  @impl true
  def init(_opts) do
    count = Picam.next_frame() |> get_image_binary_sum()
    {:ok, %{port: nil, count: count}}
  end

  @impl true
  def handle_info(:reconnect_port, state) do
    Logger.info("we're spawning a new port...")

    with port when is_port(port) <- spawn_rtmp_port() do
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
    Process.send_after(self(), :reconnect_port, 10_000)
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
  def handle_cast({:detect_motion, image}, %{port: port, count: previous_count}) do
    count = get_image_binary_sum(image)

    if count < previous_count - previous_count * 0.20 or
         count > previous_count + previous_count * 0.20 do
      Logger.debug(inspect(count))
      Logger.info("Moving")
      kill_picam()
    end

    {:noreply, %{port: port, count: count}}
  end

  defp kill_picam() do
    pid = Process.whereis(Picam.Camera)

    %{
      port: port,
      requests: _requests,
      offline: _offline,
      offline_image: offline_image,
      port_restart_interval: port_restart_interval
    } = :sys.get_state(pid)

    {:os_pid, port_pid} = Port.info(port, :os_pid)
    System.cmd("kill", ["-KILL", "#{port_pid}"])

    Process.exit(pid, :normal)
    :timer.sleep(1000)
    spawn_rtmp_port()
  end

  defp get_image_binary_sum(image) do
    image |> :binary.bin_to_list() |> Enum.sum()
  end

  defp spawn_rtmp_port() do
    Logger.info("attempting to open rtmp port")

    {target_number, twilio_number_you_own, body} =
      {Application.get_env(:mux, :phone_number), Application.get_env(:mux, :twilio_number),
       "Movement was detected and your stream has started"}

    ExTwilio.Message.create(to: target_number, from: twilio_number_you_own, body: body)
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
           "#{Application.get_env(:mux, :stream_url)}/#{Application.get_env(:mux, :stream_key)}"
         ]}
      ])
  end
end
