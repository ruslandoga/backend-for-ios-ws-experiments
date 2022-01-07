defmodule W.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, name: W.Registry, keys: :duplicate},
      {Plug.Adapters.Cowboy,
       scheme: :http, plug: Web.Endpoint, options: [dispatch: dispatch(), port: 4000]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: W.Supervisor)
  end

  defp dispatch do
    [
      {:_,
       [
         {"/ws", Web.Socket, [Web.UserSocket]},
         {:_, Plug.Cowboy.Handler, {Web.Endpoint, []}}
       ]}
    ]
  end
end
