defmodule KjogviWeb.Paths.TaxonPath do
  @moduledoc """
  Generating paths to the user's own taxon pages.
  """

  use KjogviWeb, :verified_routes

  @doc """
  Path to the user's page for a taxon (with its `book` loaded), at a page of
  its observations.
  """
  def my_taxon_path(taxon, page \\ 1)

  def my_taxon_path(%{book: book, code: code}, 1) do
    ~p"/my/taxa/#{book.slug}/#{book.version}/#{code}"
  end

  def my_taxon_path(%{book: book, code: code}, page) do
    ~p"/my/taxa/#{book.slug}/#{book.version}/#{code}/page/#{page}"
  end
end
