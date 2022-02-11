defmodule Web.UserSocket do
  @moduledoc false
  @behaviour Web.Socket
  # import Web.SocketError
  require Logger

  # plan:
  # - ~~basic auth on connect~~
  # - changesets and errors
  # - ~~process hibernation~~
  # - fullsweep after?
  # - origin check
  # - ~~test process and utilities (push / receive, integration with ecto sandbox)~~
  # - unrelated: phoenix pubsub dispatcher integration
  # - unrelated: registry dispatcher integration
  # - unrelated: pg+regsitry based cluster-wide pubsub (with more control over topology than in phoenix pubsub)
  # - ability to intercept handle_event
  # - router-like macros:
  #     handle "echo", EchoHandler, :echo
  #     defmodule EchoHandler do
  #       def echo(params, assigns) do
  #         {:ok, params, assigns}
  #       end
  #     end

  @impl true
  def connect(%{headers: %{"authorization" => "Bearer " <> token}, peer: peer}) do
    {:ok, _assigns = %{token: token, peer: peer}}
    # {:error, _status = 401,
    #  _headers = %{"www-authenticate" => "Basic", "x-reason" => "invalid-token"}}
  end

  def connect(_req) do
    {:error, _status = 401, _headers = %{"www-authenticate" => "Basic"}}
  end

  @impl true
  def init(%{token: token, peer: {ip, port}}) do
    Logger.metadata(token: token, peer: "#{:inet.ntoa(ip)}:#{port}")
    W.PubSub.subscribe("user_socket")
    W.PubSub.subscribe("user_socket:" <> token)
    {:ok, _assigns = %{}}
  end

  @impl true
  def handle_event("echo", params, assigns) do
    {:ok, params, assigns}
  end

  def handle_event("empty", _params, assigns) do
    {:ok, assigns}
  end

  def handle_event("error", _params, assigns) do
    {:error, %{code: 500}, assigns}
  end

  def handle_event("call", %{"id" => user_id}, assigns) do
    case user_id do
      "123" ->
        call = %{
          "id" => "456",
          "profile" => %{"name" => "John"},
          "ice_servers" => ["stun://localhost:4000"],
          "date" => DateTime.truncate(DateTime.utc_now(), :second)
        }

        {:ok, call, assigns}

      "234" ->
        # %Ecto.Changeset{errors: %{}}
        # changeset = %{}
        # {:error, error(:changeset, changeset), assigns}
        {:ok, assigns}
    end
  end

  def handle_event("timeout", _params, assigns) do
    :timer.sleep(500)
    {:ok, assigns}
  end

  def handle_event("crash", _params, _assigns) do
    raise "oops, crash ..."
  end

  @impl true
  def handle_info({SomeModule, :event, id}, assigns) do
    {[build("event", %{"id" => id})], assigns}
  end

  def handle_info(_message, assigns) do
    {_noreply = [], assigns}
  end

  defp build(event, payload), do: [event, payload]

  @impl true
  def terminate(reason, _assigns) do
    Logger.warn(["terminated: ", inspect(reason)])
  end
end
