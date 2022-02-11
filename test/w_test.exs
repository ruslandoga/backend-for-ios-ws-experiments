defmodule WTest do
  use ExUnit.Case

  defmodule TestSocket do
    use GenServer

    def start_link(ws_state) do
      GenServer.start_link(__MODULE__, ws_state)
    end

    @impl true
    def init(ws_state) do
      Web.Socket.websocket_init(ws_state)
    end

    @impl true
    def handle_call(frame, _from, ws_state) do
      {frames, ws_state} = Web.Socket.websocket_handle(frame, ws_state)
      {:reply, frames, ws_state}
    end

    @impl true
    def handle_info(message, ws_state) do
      {frames, ws_state} = Web.Socket.websocket_info(message, ws_state)
      parent = List.last(Process.get(:"$ancestors"))

      Enum.each(frames, fn {:text, iodata} ->
        payload = iodata |> IO.iodata_to_binary() |> Jason.decode!()
        send(parent, payload)
      end)

      {:noreply, ws_state}
    end
  end

  def connect(handler, req) do
    case handler.connect(req) do
      {:ok, assigns} -> start_supervised({TestSocket, [handler | assigns]})
      {:error, _status_code, _headers} = error -> error
    end
  end

  def push(socket, event, data) do
    ref = :rand.uniform(100_000)
    text = Jason.encode!([ref, event, data])
    [text: text] = GenServer.call(socket, {:text, text})
    [^ref, status, payload] = Jason.decode!(text)

    case status do
      "ok" -> {:ok, payload}
      "error" -> {:error, payload}
    end
  end

  test "failure: connect" do
    assert {:error, 401, %{"www-authenticate" => "Basic"}} =
             connect(Web.UserSocket, %{headers: []})
  end

  test "success: connect" do
    req = %{headers: %{"authorization" => "Bearer token"}, peer: {{127, 0, 0, 1}, 54056}}
    assert {:ok, socket} = connect(Web.UserSocket, req)
    assert Process.alive?(socket)
  end

  describe "push" do
    setup do
      req = %{headers: %{"authorization" => "Bearer token"}, peer: {{127, 0, 0, 1}, 54056}}
      {:ok, socket} = connect(Web.UserSocket, req)
      {:ok, socket: socket}
    end

    test "success: push", %{socket: socket} do
      assert {:ok, %{"ha" => "2022-01-01"}} = push(socket, "echo", %{"ha" => ~D[2022-01-01]})
    end

    test "failure: push", %{socket: socket} do
      assert {:error, [5000, "internal server error"]} =
               push(socket, "server-error", %{"ha" => "ha"})
    end

    test "success: handle_info", %{socket: socket} do
      send(socket, {SomeModule, :event, 123})
      assert_receive ["event", %{"id" => 123}]
    end
  end
end
