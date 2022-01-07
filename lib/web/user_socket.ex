defmodule Web.UserSocket do
  @moduledoc false
  @behaviour Web.Socket
  import Web.SocketError

  @impl true
  def connect(%{headers: %{"authorization" => "Bearer " <> token}, peer: peer}) do
    {:ok, _assigns = %{token: token, peer: peer}}
  end

  def connect(_req) do
    {:error, _forbidden = 403}
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
    {:error, error(:user_busy), assigns}
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
        {:error, error(:call_not_allowed), assigns}
    end
  end

  def handle_event("crash", _params, _assigns) do
    raise "oops, crash ..."
  end

  @impl true
  def handle_info(_message, assigns) do
    {_noreply = [], assigns}
  end

  @impl true
  def terminate(_reason, _assigns) do
  end
end
