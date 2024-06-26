defmodule Animina.Repo.Migrations.AddBadPassword do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_postgres.generate_migrations`
  """

  use Ecto.Migration

  def up do
    create table(:bad_passwords, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v4()"), primary_key: true
      add :value, :citext, null: false
    end

    create unique_index(:bad_passwords, [:value], name: "bad_passwords_value_index")
  end

  def down do
    drop_if_exists unique_index(:bad_passwords, [:value], name: "bad_passwords_value_index")

    drop table(:bad_passwords)
  end
end
