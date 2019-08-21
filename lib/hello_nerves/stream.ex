# GenStage A - We read jpg files from /tmp and put them in a queue, deleting them after, and passing them to the next stage
# If there is movement, let's update our state and send information downstream to the next GenStage
defmodule HelloNerves.Stream do
  use GenStage
  require Logger

  @motion_sensitivity 0.005

  def start_link(_args) do
    GenStage.start_link(HelloNerves.Stream, [], name: HelloNerves.Stream)
  end

  def init(_args) do
    {:producer, []}
  end

  @doc "Sends an event and returns only after the event is dispatched."
  def sync_notify(event, timeout \\ 0) do
    GenStage.call(__MODULE__, {:notify, event}, timeout)
  end

  def handle_call({:notify, event}, _from, state) do
    # Dispatch immediately
    {:reply, :ok, [event], state}
  end

  def handle_demand(_demand, files) do
    IO.inspect("in demand")
    Logger.info("in demand")
    processed_files = process_files()
    {:noreply, processed_files, []}
  end

  defp process_files() do
    directory = "/tmp"
    {:ok, files} = File.ls(directory)
    Enum.map(files, fn(file) -> process_file(file))
  end

  defp process_file(directory, file_name) do
    file_path = "#{directory}/#{file_name}"

    with {:ok, file} <- File.open(file_path),
         :ok <- File.rm(file_path) do
      file
    else
      _ ->
        Logger.info("Could not process the file.")
        nil
    end
  end
end
