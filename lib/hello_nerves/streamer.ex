defmodule HelloNerves.Streamer do
  @moduledoc """
  Plug for streaming an image
  """
  import Plug.Conn
  require Logger

  @behaviour Plug
  @boundary "yUhJacquiManziElixirConfuIuiHjK"

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    Picam.set_size(1080, 0)

    conn
    |> put_resp_header("Age", "0")
    |> put_resp_header("Cache-Control", "no-cache, private")
    |> put_resp_header("Pragma", "no-cache")
    |> put_resp_header("Content-Type", "multipart/x-mixed-replace; boundary=#{@boundary}")
    |> send_chunked(200)
    |> send_frames()
  end

  defp send_frames(conn) do
    frame = Picam.next_frame()
    send_frame(conn, frame)
    send_frames(conn)
  end

  # Sending the jpeg chunks to the browser
  defp send_frame(conn, frame) do
    size = byte_size(frame)
    header = "------#{@boundary}\r\nContent-Type: image/jpeg\r\nContent-length: #{size}\r\n\r\n"
    footer = "\r\n"

    with {:ok, conn} <- chunk(conn, header),
         {:ok, conn} <- chunk(conn, frame),
         {:ok, conn} <- chunk(conn, footer),
         do: conn
  end
end
