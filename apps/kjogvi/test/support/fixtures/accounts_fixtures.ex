defmodule Kjogvi.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Kjogvi.Accounts` context.
  """

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def unique_user_nickname, do: "user#{System.unique_integer([:positive])}"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      nickname: unique_user_nickname(),
      password: valid_user_password()
    })
  end

  # Registration stamps the site default taxonomy, so an explicitly requested
  # `default_book_signature` (including nil) is applied after the insert.
  def user_fixture(attrs \\ %{}) do
    {signature, attrs} = attrs |> Map.new() |> Map.pop(:default_book_signature, :stamped)

    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Kjogvi.Accounts.register_user()

    put_book_signature(user, signature)
  end

  defp put_book_signature(user, :stamped), do: user

  defp put_book_signature(user, signature) do
    user
    |> Ecto.Changeset.change(default_book_signature: signature)
    |> Kjogvi.Repo.update!()
  end

  def admin_fixture(attrs \\ %{}) do
    {signature, attrs} = attrs |> Map.new() |> Map.pop(:default_book_signature, :stamped)

    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Kjogvi.Accounts.register_admin()

    put_book_signature(user, signature)
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
