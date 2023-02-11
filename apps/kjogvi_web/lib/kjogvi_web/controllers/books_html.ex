defmodule KjogviWeb.BooksHTML do
  @moduledoc false

  use KjogviWeb, :html

  import KjogviWeb.TimeComponents

  embed_templates "books_html/*"

  def index(assigns) do
    ~H"""
    <.table id="books" rows={@books}>
      <:col :let={book} label="slug">
        <a href={~p"/taxonomy/#{book.slug}/#{book.version}"}>
          <%= book.slug %>
        </a>
      </:col>
      <:col :let={book} label="version"><%= book.version %></:col>
      <:col :let={book} label="name"><%= book.name %></:col>
      <:col :let={book} label="description"><%= book.description %></:col>
      <:col :let={book} label="imported">
        <.datetime time={book.imported_at} />
      </:col>
    </.table>
    """
  end

  def show(assigns) do
    ~H"""
    <.header>
      <%= @book.name %>
      <:subtitle><%= @book.description %></:subtitle>
    </.header>
    """
  end
end
