defmodule Web.Endpoint do
  @moduledoc false
  use Plug.Builder

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason

  plug Plug.Logger
  plug Web.Router
end
