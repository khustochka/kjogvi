defmodule KjogviWeb.TaxaLive.Table do
  use KjogviWeb, :live_component

  @minimum_search_term_length 3

  import KjogviWeb.TaxaComponents
  import KjogviWeb.PaginationComponents

  @impl true
  def update(%{book: book, page_num: page_num}, socket) do
    {:ok,
     socket
     |> assign(:book, book)
     |> assign(:page_num, page_num)
     |> assign_search_state(nil)
     |> assign_taxa
    }
  end

  @impl true
  def handle_event("term_updated", %{"_target" => ["search_term"], "search_term" => search_term}, socket) do
    {:noreply,
      socket
      |> assign_search_state(search_term)
      |> assign_taxa
    }
  end

  defp category_to_color(cat) do
    case cat do
      "species" -> "bg-green-500"
      "issf" -> "bg-blue-500"
      c when c in ["slash", "spuh", "form"] -> "bg-rose-400"
      c when c in ["domestic", "intergrade", "hybrid"] -> "bg-zinc-400"
      _ -> "bg-zinc-400"
    end
  end

  defp assign_search_state(socket, nil = _search_term) do
    socket
    |> assign(:search_term, nil)
    |> assign(:search_enabled, false)
  end

  defp assign_search_state(socket, "" = _search_term) do
    assign_search_state(socket, nil)
  end

  defp assign_search_state(socket, search_term) when is_binary(search_term) do
    normalized_term = String.trim(search_term)
    socket
    |> assign(:search_term, normalized_term)
    |> assign(:search_enabled, String.length(normalized_term) >= @minimum_search_term_length)
  end

  defp assign_taxa(socket) do
    socket
    |> assign(:taxa, get_taxa(socket.assigns))
  end

  defp get_taxa(%{book: book, search_enabled: false, page_num: page_num}) do
    Ornitho.Finder.Taxon.page(book, page_num, with_parent_species: true)
  end

  defp get_taxa(%{book: book, search_enabled: true, search_term: search_term}) do
    Ornitho.Finder.Taxon.search(book, search_term, limit: 15, with_parent_species: true)
  end
end
