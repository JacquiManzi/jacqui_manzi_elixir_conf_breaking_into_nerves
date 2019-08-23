defmodule HelloNerves.Recorder do
  use GenStage
  require Logger

  @motion_sensitivity 0.09
  @directory "/tmp/frames"

  def start_link(args) do
    GenStage.start_link(HelloNerves.Recorder, args, name: HelloNerves.Recorder)
  end

  def init(_args) do
    {:consumer,
     %{is_moving: false, count: 0, sample_frame: nil, motion_interval: 500, motion_active: false}}
  end

  def handle_events(frames, _from, state) do
    :timer.sleep(800)
    process_files(frames)
    {:noreply, [], state}
  end

  defp process_files(files) do
    Enum.map(files |> Enum.take(-40), fn file -> process_file(file) end)
  end

  defp process_file(file_name) do
    file_path = "#{@directory}/#{file_name}"

    with {:ok, file} <- File.read(file_path),
         :ok <- File.rm(file_path) do
      GenStage.cast(self(), {:detect_motion, file})
      file
    else
      _ ->
        nil
    end
  end

  @impl true
  def handle_cast({:detect_motion, jpeg}, %{
        is_moving: _moving,
        count: previous_count,
        sample_frame: _sample_frame,
        motion_interval: motion_interval,
        motion_active: motion_active
      }) do
    count = jpeg |> :binary.bin_to_list() |> Enum.sum()
    percentage = previous_count * @motion_sensitivity
    is_moving = count < previous_count - percentage or count > previous_count + percentage
    Process.send(self(), :set_motion_state, [])

    {:noreply, [],
     %{
       is_moving: is_moving,
       count: count,
       sample_frame: jpeg,
       motion_interval: motion_interval,
       motion_active: motion_active
     }}
  end

  @impl true
  def handle_info(
        :set_motion_state,
        %{
          is_moving: is_moving,
          count: count,
          sample_frame: jpeg,
          motion_interval: motion_interval,
          motion_active: motion_active
        } = state
      ) do
    Logger.info(is_moving)
    Logger.info(motion_interval)
    pid = Process.whereis(MotionDetectionWorker)

    cond do
      is_moving ->
        if !motion_active do
          Logger.info("Setting motion active state")
          GenStage.cast(pid, {:motion_detected, true})

          {:noreply, [],
           %{
             is_moving: is_moving,
             count: count,
             sample_frame: jpeg,
             motion_interval: 2000,
             motion_active: true
           }}
        else
          {:noreply, [],
           %{
             is_moving: is_moving,
             count: count,
             sample_frame: jpeg,
             motion_interval: 2000,
             motion_active: motion_active
           }}
        end

      !is_moving and motion_active ->
        if motion_interval == 0 do
          Logger.info("Setting motion unactive state")
          GenStage.cast(pid, {:motion_undetected, true})

          {:noreply, [],
           %{
             is_moving: is_moving,
             count: count,
             sample_frame: jpeg,
             motion_interval: motion_interval,
             motion_active: false
           }}
        else
          {:noreply, [],
           %{
             is_moving: is_moving,
             count: count,
             sample_frame: jpeg,
             motion_interval: motion_interval - 1,
             motion_active: motion_active
           }}
        end

      !is_moving and !motion_active ->
        {:noreply, [],
         %{
           is_moving: is_moving,
           count: count,
           sample_frame: jpeg,
           motion_interval: 0,
           motion_active: motion_active
         }}
    end
  end
end
