defmodule Animina do
  @moduledoc """
  Animina keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @doc """
  Pubsub broadcast
  """
  def broadcast(topic, _event, payload) do
    Phoenix.PubSub.broadcast(Animina.PubSub, topic, payload)
  end
end
