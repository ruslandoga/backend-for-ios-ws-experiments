defmodule W.PubSub do
  @moduledoc false

  @registry W.Registry

  def subscribe(key, meta \\ []) do
    Registry.register(@registry, key, meta)
  end

  def broadcast(key, message) do
    iodata = Jason.encode_to_iodata!(message)

    Registry.dispatch(@registry, key, fn entries ->
      Enum.each(entries, fn entry ->
        {pid, _meta} = entry
        send(pid, {:fastlane, iodata})
      end)
    end)
  end

  def count(key) do
    Registry.count_match(@registry, key, :_)
  end
end
