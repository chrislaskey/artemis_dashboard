defmodule Artemis.CloudantChange do
  @moduledoc """
  Broadcast cloudant change records
  """

  defmodule Data do
    defstruct [
      :action,
      :document,
      :id,
      :schema
    ]
  end

  def topic(schema), do: "private:artemis:cloudant-changes:#{Artemis.Helpers.dashcase(schema)}"

  def broadcast(%{id: _, schema: schema} = data) do
    payload = struct(Data, data)

    :ok = ArtemisPubSub.broadcast(topic(schema), payload.action, payload)

    data
  end

  def broadcast(data), do: data
end
