defmodule Web.Socket do
  @moduledoc false
  import Web.SocketError
  @behaviour :cowboy_websocket
  require Logger

  @type assigns :: term

  @callback connect(:cowbot.req()) :: {:ok, assigns} | {:error, :cowboy.status_code()}
  @callback init(assigns :: map) :: {:ok, assigns}

  @callback handle_event(event :: String.t(), params :: term, assigns) ::
              {:ok, assigns}
              | {:ok, term, assigns}
              | {:error, [pos_integer() | String.t()], assigns}

  @callback handle_info(message :: term, assigns) ::
              {pushes :: [String.t() | term], assigns}

  @callback terminate(:cowboy_websocket.terminate_reason(), assigns) :: any

  @impl true
  def init(req, [handler] = state) do
    # TODO hibernate after 15 secs
    # TODO check origin?
    case handler.connect(req) do
      {:ok, assigns} ->
        {:cowboy_websocket, req, [handler | assigns], _opts = %{}}

      {:error, status_code} ->
        # TODO
        {:ok, :cowboy_req.reply(status_code, req), state}
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

        {:error, [_code, _reason] = payload, assigns} ->
          text = Jason.encode_to_iodata!([ref, "error", payload])
          {[text: text], [handler | assigns]}
      end
    rescue
      e ->
        Logger.error(Exception.format(:error, e, __STACKTRACE__))
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
