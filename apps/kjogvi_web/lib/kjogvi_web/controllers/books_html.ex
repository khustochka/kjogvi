defmodule KjogviWeb.BooksHTML do
  @moduledoc false

  use KjogviWeb, :html

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
