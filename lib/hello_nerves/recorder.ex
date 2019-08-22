# GenStage B - Get's jpegs from GenStage A and does some basic motion calcuation on them,
# If this is motion, let's start streaming to mux
# If there isn't motion for a x amount of time, close the port and stop streaming to mux
# This starts a stream and sends to Mux
defmodule HelloNerves.Recorder do
  use GenStage
  require Logger

  @motion_sensitivity 0.08
  @directory "/tmp/frames"

  def start_link(args) do
    GenStage.start_link(HelloNerves.Recorder, args, name: HelloNerves.Recorder)
  end

  def init(_args) do
    {:consumer, %{is_moving: false, count: 0}}
  end

  def handle_events(frames, _from, state) do
    :timer.sleep(1000)
    process_files(frames)
    {:noreply, [], state}
  end

  defp process_files(files) do
    Enum.map(files |> Enum.take(-30), fn file -> process_file(file) end)
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

  def handle_cast({:detect_motion, jpeg}, %{is_moving: _moving, count: previous_count}) do
    count = jpeg |> :binary.bin_to_list() |> Enum.sum()
    percentage = previous_count * @motion_sensitivity
    is_moving = count < previous_count - percentage or count > previous_count + percentage
    if is_moving, do: Logger.info(is_moving)
    {:noreply, [], %{is_moving: is_moving, count: count}}
  end
end
