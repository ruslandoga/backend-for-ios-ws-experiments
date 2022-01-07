defmodule Web.SocketError do
  @moduledoc false

  errors = %{
    call_not_allowed: [123, "call is not allowed"],
    user_busy: [45, "user is busy"],
    internal: [5000, "internal server error"]
  }

  for {key, [code, description]} <- errors do
    def error(unquote(key)), do: [unquote(code), unquote(description)]
  end
end
