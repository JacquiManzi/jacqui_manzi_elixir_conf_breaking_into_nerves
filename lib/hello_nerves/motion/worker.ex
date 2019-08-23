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
        %{port: _port, count: count, stream_allowed: stream_allowed, ffmpeg_info: ffmpeg_info} =
          state
      ) do
    Logger.info("we're spawning a new port...")

    with new_port when is_port(new_port) <- spawn_rtmp_port() do
      {:noreply,
       %{port: new_port, count: count, stream_allowed: stream_allowed, ffmpeg_info: ffmpeg_info}}
    else
      _ ->
        Process.send_after(self(), :reconnect_port, 10_000)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(
        :allow_streaming,
        %{port: port, count: count, stream_allowed: _stream_allowed, ffmpeg_info: ffmpeg_info}
      ) do
    Logger.info("Enabling streaming")

    {:noreply, %{port: port, count: count, stream_allowed: true, ffmpeg_info: ffmpeg_info}}
  end

  @impl true
  def handle_info(
        :restart_picam,
        %{port: port, count: count, stream_allowed: _stream_allowed, ffmpeg_info: ffmpeg_info}
      ) do
    Logger.info("Restarting the Picam port process and stopping our stream")

    {:os_pid, port_pid} = Port.info(port, :os_pid)
    System.cmd("kill", ["-KILL", "#{port_pid}"])
    :timer.sleep(5000)
    pid = Process.whereis(Picam.Camera)

    Process.send(pid, :reconnect_port, [])
    {:noreply, %{port: port, count: count, stream_allowed: false, ffmpeg_info: ffmpeg_info}}
  end

  @impl true
  def handle_info(
        :spawn_rtmp_port,
        %{port: _port, count: count, stream_allowed: _stream_allowed, ffmpeg_info: ffmpeg_info} =
          state
      ) do
    Logger.info("attempting to open rtmp port")

    with {target_number, twilio_number_you_own, body} <-
           {Application.get_env(:mux, :phone_number), Application.get_env(:mux, :twilio_number),
            "Movement was detected and your stream has started"},
         {:ok, _} <-
           ExTwilio.Message.create(to: target_number, from: twilio_number_you_own, body: body) do
      rtmp_port = spawn_rtmp_port()
      {:noreply, %{port: rtmp_port, count: count, stream_allowed: true, ffmpeg_info: ffmpeg_info}}
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
  def handle_cast({:detect_motion, image}, %{
        port: port,
        count: previous_count,
        stream_allowed: stream_allowed,
        ffmpeg_info: ffmpeg_info
      }) do
    count = get_image_binary_sum(image)
    percentage = previous_count * @motion_sensitivity

    if count < previous_count - percentage or
         count > previous_count + percentage do
      Logger.info("Moving: #{count}}")

      if stream_allowed, do: kill_picam()
    end

    {:noreply,
     %{port: port, count: count, stream_allowed: stream_allowed, ffmpeg_info: ffmpeg_info}}
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
    executable = System.find_executable("sh")

    Port.open({:spawn_executable, executable}, [
      :stderr_to_stdout,
      :use_stdio,
      :exit_status,
      :binary,
      {:args,
       [
         "-c",
         "raspivid -o - -t 0 --mode 1 -a 1036 -fps 30 -b 3000000 | ffmpeg -re -ar 44100 -ac 2 -acodec pcm_s16le -f s16le -ac 2 -i /dev/zero -f h264 -r 30 -i - -vcodec copy -acodec aac -ab 64k -r 30 -g 50 -strict experimental -f flv #{
           Application.get_env(:mux, :stream_url)
         }/#{Application.get_env(:mux, :stream_key)}"
       ]}
    ])
  end
end
