defmodule HelloNerves.Router do
  use Plug.Router
  require Logger;

  plug :match
  plug :dispatch
  IO.inspect "Got router"
  Logger.info("got  router")
  get "/test" do
    markup = """
    <html>
    <head>
      <title>Picam Video Stream</title>
    </head>
    <body>
      <img src="video.mjpg" />
    </body>
    </html>
    """
    conn
    |> put_resp_header("Content-Type", "text/html")
    |> send_resp(200, markup)
  end

  forward "/video.mjpg", to: HelloNerves.Streamer

  match _ do
    send_resp(conn, 404, "Oops. Try /")
  end

end

