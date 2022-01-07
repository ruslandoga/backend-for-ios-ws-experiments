defmodule Web.UserSocket do
  @moduledoc false

  @behaviour :cowboy_websocket
  @registry W.Registry

  @impl true
  def init(req, state) do
    IO.inspect([req: req, state: state, pid: self()], label: "init")
    {:cowboy_websocket, req, state}
  end

  @impl true
  def websocket_init(state) do
    Registry.register(@registry, "user_socket", [])
    IO.inspect([state: state, pid: self()], label: "websocket_init")
    {:ok, _state = %{}}
  end

  @impl true
  def websocket_handle({:text, "ping"}, state) do
    IO.inspect([state: state], label: "ping")
    {:reply, {:text, "pong"}, state}
  end

  def websocket_handle({:text, message}, state) do
    IO.inspect([message: message, state: state, pid: self()], label: "message")
    {:ok, state}
  end

  @impl true
  def websocket_info({:fastlane, push}, state) do
    IO.inspect([fastlane: push], label: "fastlane")
    {:reply, {:text, push}, state}
  end
end
