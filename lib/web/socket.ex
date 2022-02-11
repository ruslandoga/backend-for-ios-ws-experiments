defmodule Web.Socket do
  @moduledoc false
  import Web.SocketError
  @behaviour :cowboy_websocket
  require Logger

  @type assigns :: term
  @type fail_details :: %{(atom | String.t()) => [String.t()] | fail_details}
  @type error :: %{optional(:code) => pos_integer(), optional(:message) => String.t()}

  @callback connect(:cowbot.req()) ::
              {:ok, assigns} | {:error, :cowboy.status_code(), :cowboy.http_headers()}

  @callback init(assigns :: map) :: {:ok, assigns}

  @callback handle_event(event :: String.t(), params :: term, assigns) ::
              {:ok, assigns}
              | {:ok, term, assigns}
              | {:fail, fail_details, assigns}
              | {:error, error, assigns}

  @callback handle_info(message :: term, assigns) ::
              {pushes :: [String.t() | term], assigns}

  @callback terminate(:cowboy_websocket.terminate_reason(), assigns) :: any

  @impl true
  def init(req, [handler] = state) do
    # TODO hibernate after 15 secs
    # TODO check origin?

    IO.inspect(req)

    # %{
    #   bindings: %{},
    #   body_length: 0,
    #   cert: :undefined,
    #   has_body: false,
    #   headers: %{
    #     "accept" => "*/*",
    #     "accept-encoding" => "gzip, deflate",
    #     "accept-language" => "en-US,en;q=0.9", # might be useful for localization
    #     "connection" => "Upgrade",
    #     "host" => "localhost:4000", # might be useful for check_origin
    #     "sec-websocket-extensions" => "permessage-deflate",
    #     "sec-websocket-key" => "19huyUYIn3eg5oXGFcqITQ==",
    #     "sec-websocket-version" => "13",
    #     "upgrade" => "websocket",
    #     "user-agent" => "ws/1 CFNetwork/1327.0.4 Darwin/21.2.0" # <- might be useful to automatically get the app version
    #   },
    #   host: "localhost",
    #   host_info: :undefined,
    #   method: "GET",
    #   path: "/ws",
    #   path_info: :undefined,
    #   peer: {{127, 0, 0, 1}, 54056}, # might be useful for remote_ip
    #   pid: #PID<0.439.0>,
    #   port: 4000,
    #   qs: "", # might be useful for screen_width or screen width can be passed into user-agent lol
    #   ref: Web.Endpoint.HTTP,
    #   scheme: "http",
    #   sock: {{127, 0, 0, 1}, 4000},
    #   streamid: 12,
    #   version: :"HTTP/1.1"
    # }

    case handler.connect(req) do
      {:ok, assigns} ->
        {:cowboy_websocket, req, [handler | assigns], _opts = %{}}

      {:error, status_code, headers} ->
        {:ok, :cowboy_req.reply(status_code, headers, req), state}
    end
  end

  @impl true
  def websocket_init([handler | assigns]) do
    {:ok, assigns} = handler.init(assigns)
    {:ok, [handler | assigns]}
  end

  @impl true
  def websocket_handle({:ping, ping}, state) do
    Logger.debug(["received ping ", IO.inspect(ping)])
    {[pong: ping], state}
  end

  # inspo https://github.com/omniti-labs/jsend
  def websocket_handle({:text, message}, [handler | assigns] = state) do
    Logger.debug(["received ", message])
    [ref, event, payload] = Jason.decode!(message)

    # TODO this can lead to unresolvable errors
    # maybe just send close frame?
    try do
      case handler.handle_event(event, payload, assigns) do
        {:ok, assigns} ->
          text = Jason.encode_to_iodata!([ref, "ok", %{}])
          {[text: text], [handler | assigns]}

        {:ok, payload, assigns} ->
          text = Jason.encode_to_iodata!([ref, "ok", payload])
          {[text: text], [handler | assigns]}

        # {:fail, details, assigns} ->
        #   text = Jason.encode_to_iodata!([ref, "fail", details])
        #   {[text: text], [handler | assigns]}

        {:error, [_code, _status] = error, assigns} ->
          text = Jason.encode_to_iodata!([ref, "error", error])
          {[text: text], [handler | assigns]}
      end
    rescue
      e ->
        Logger.error(Exception.format(:error, e, __STACKTRACE__))
        # text = Jason.encode_to_iodata!([ref, "error", %{code: 500}])
        text = Jason.encode_to_iodata!([ref, "error", error(:internal)])
        {[text: text], state}
    end
  end

  @impl true
  def websocket_info({:fastlane, push}, state) do
    {[text: push], state}
  end

  def websocket_info(message, [handler | assigns]) do
    {pushes, assigns} = handler.handle_info(message, assigns)

    frames =
      Enum.map(pushes, fn [_event, _payload] = push ->
        {:text, Jason.encode_to_iodata!(push)}
      end)

    {frames, [handler | assigns]}
  end

  @impl true
  def terminate(reason, _req, [handler | assigns]) do
    handler.terminate(reason, assigns)
    :ok
  end
end
