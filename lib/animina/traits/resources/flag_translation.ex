defmodule Animina.Traits.FlagTranslation do
  @moduledoc """
  Translations of the flags.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :language, :string, allow_nil?: false
    attribute :name, :ci_string, allow_nil?: false
    attribute :hashtag, :ci_string, allow_nil?: false
  end

  relationships do
    belongs_to :flag, Animina.Traits.Flag do
      attribute_writable? true
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]
  end

  code_interface do
    define_for Animina.Traits
    define :read
    define :create
    define :update
    define :destroy
    define :by_id, get_by: [:id], action: :read
  end

  identities do
    identity :unique_name, [:name, :language, :flag_id]
    identity :hashtag, [:hashtag, :language]
  end

  postgres do
    table "traits_flag_translations"
    repo Animina.Repo
  end

  # defp validate_language_code_length(changes) do
  #   case Ash.Changes.get_change(changes, :language_code) do
  #     {:ok, code} when byte_size(code) == 2 -> :ok
  #     {:ok, _code} -> {:error, "language_code must be exactly 2 characters long"}
  #     # No change to language_code, so no need to validate
  #     :error -> :ok
  #   end
  # end
end
