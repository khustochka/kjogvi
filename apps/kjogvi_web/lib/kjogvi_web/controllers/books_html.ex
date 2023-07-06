defmodule KjogviWeb.BooksHTML do
  @moduledoc false

  use KjogviWeb, :html

  import KjogviWeb.TimeComponents
  import KjogviWeb.TaxaComponents

  embed_templates "books_html/*"

  def index(assigns) do
    ~H"""
    <.header>
      <%= assigns[:page_title] %>
    </.header>
    <.simpler_table id="books" rows={@books}>
      <:col :let={{book, _}} label="slug">
        <a href={~p"/taxonomy/#{book.slug}/#{book.version}"} class="font-semibold text-zinc-900">
          <%= book.slug %>
        </a>
      </:col>
      <:col :let={{book, _}} label="version"><%= book.version %></:col>
      <:col :let={{book, _}} label="name"><%= book.name %></:col>
      <:col :let={{book, _}} label="description"><%= book.description %></:col>
      <:col :let={{_, %{taxa_count: taxa_count}}} label="taxa"><%= taxa_count %></:col>
      <:col :let={{book, _}} label="imported">
        <.datetime time={book.imported_at} />
      </:col>
    </.simpler_table>
    """
  end

  def show(assigns) do
    ~H"""
    <.header>
      <%= @book.name %>
      <:subtitle><%= @book.description %></:subtitle>
    </.header>
    <.simpler_table id="taxa" rows={@taxa}>
      <:col :let={taxon} label="no"><%= taxon.sort_order %></:col>
      <:col :let={taxon} label="code"><%= taxon.code %></:col>
      <:col :let={taxon} label="name">
        <div class="font-semibold text-zinc-900"><%= taxon.name_sci %></div>
        <div><%= taxon.name_en %></div>
      </:col>
      <:col :let={taxon} label="category"><%= taxon.category %></:col>
      <:col :let={taxon} label="taxonomy">
        <div><%= taxon.order %></div>
        <div><%= taxon.family %></div>
      </:col>
    </.simpler_table>
    """
  end
end
