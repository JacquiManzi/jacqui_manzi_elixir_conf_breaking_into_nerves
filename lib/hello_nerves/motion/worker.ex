defmodule HelloNerves.Motion.Worker do
  use GenServer
  require Logger

  @motion_sensitivity 0.02

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: MotionDetectionWorker)
  end

  @impl true
  def init(_opts) do
    count = Picam.next_frame() |> get_image_binary_sum()
    {:ok, %{port: nil, count: count, stream_allowed: false, ffmpeg_info: false}}
  end

  @impl true
  def handle_info(
        :reconnect_port,
        state
      ) do
    Logger.info("we're spawning a new port...")

    with new_port when is_port(new_port) <- spawn_rtmp_port() do
      {:noreply, %{state | port: new_port}}
    else
      _ ->
        Process.send_after(self(), :reconnect_port, 10_000)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(
        :allow_streaming,
        state
      ) do
    Logger.info("Enabling streaming")

    {:noreply, %{state | stream_allowed: true}}
  end

  @impl true
  def handle_info(
        {_, {:ffmpeg_info, enabled}},
        state
      ) do
    {:noreply, %{state | allow_ffmpeg_info: enabled}}
  end

  @impl true
  def handle_info(
        :restart_picam,
        state = %{port: port}
      ) do
    Logger.info("Restarting the Picam port process and stopping our stream")

    {:os_pid, port_pid} = Port.info(port, :os_pid)
    System.cmd("kill", ["-KILL", "#{port_pid}"])
    :timer.sleep(5000)
    pid = Process.whereis(Picam.Camera)

    Process.send(pid, :reconnect_port, [])
    {:noreply, %{state | stream_allowed: false}}
  end

  @impl true
  def handle_info(
        :spawn_rtmp_port,
        state
      ) do
    Logger.info("attempting to open rtmp port")

    with {target_number, twilio_number_you_own, body} <-
           {Application.get_env(:ex_twilio, :phone_number), Application.get_env(:ex_twilio, :twilio_number),
            "Movement was detected and your stream has started"},
         {:ok, _} <-
           ExTwilio.Message.create(to: target_number, from: twilio_number_you_own, body: body) do
      rtmp_port = spawn_rtmp_port()
      {:noreply, %{state | port: rtmp_port, stream_allowed: false}}
    else
      _ -> {:noreply, state}
    end
  end

  @impl true
  def handle_info({_, {:exit_status, status}}, state) do
    Logger.info("got exit status: #{status}")
    {:noreply, state}
  end

  @impl true
  def handle_info({_port, {:data, text_line}}, state) do
    if state.ffmpeg_info, do: Logger.info("Latest output: #{text_line}")
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast(
        {:detect_motion, image},
        state = %{
          count: previous_count,
          stream_allowed: stream_allowed
        }
      ) do
    count = get_image_binary_sum(image)
    percentage = previous_count * @motion_sensitivity

    if count < previous_count - percentage or
         count > previous_count + percentage do
      Logger.info("Moving: #{count}")

      if stream_allowed, do: kill_picam()
    end

    {:noreply, %{state | count: count}}
  end

  defp kill_picam() do
    pid = Process.whereis(Picam.Camera)

    %{
      port: port,
      requests: _requests,
      offline: _offline,
      offline_image: _offline_image,
      port_restart_interval: _port_restart_interval
    } = :sys.get_state(pid)

    with {:os_pid, port_pid} <- Port.info(port, :os_pid) do
      System.cmd("kill", ["-KILL", "#{port_pid}"])
      Process.send_after(self(), :spawn_rtmp_port, 1000)
    else
      e ->
        Logger.debug(inspect(e))
        Logger.info("Could not kill picam process")
    end
  end

  defp get_image_binary_sum(image) do
    image |> :binary.bin_to_list() |> Enum.sum()
  end

  defp spawn_rtmp_port() do
    executable = System.find_executable("ffmpeg")

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
