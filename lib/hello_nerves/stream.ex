defmodule HelloNerves.Stream do
  use GenStage
  require Logger

  @directory "/tmp/frames"

  def start_link(_args) do
    GenStage.start_link(HelloNerves.Stream, [], name: HelloNerves.Stream)
  end

  def init(_args) do
    {:producer, []}
  end

  def sync_notify(event, timeout \\ 0) do
    GenStage.call(__MODULE__, {:notify, event}, timeout)
  end

  def handle_call({:notify, event}, _from, state) do
    {:reply, :ok, [event], state}
  end

  def handle_demand(demand, []) do
    with {:ok, files} <- File.ls(@directory) do
      Logger.info(length(files))
      {:noreply, files, []}
    else
      _ ->
        Logger.info("too many files open")
        {:noreply, [], []}
    end
  end
end
