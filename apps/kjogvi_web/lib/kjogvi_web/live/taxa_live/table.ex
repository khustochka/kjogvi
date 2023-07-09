defmodule KjogviWeb.TaxaLive.Table do
  use KjogviWeb, :live_component

  import KjogviWeb.TaxaComponents
  import KjogviWeb.PaginationComponents

  @impl true
  def update(%{book: book, page_num: page_num}, socket) do
    taxa = Ornitho.Finder.Taxon.page(book, page_num, %{with_parent_species: true})

    {:ok,
     socket
     |> assign(:book, book)
     |> assign(:page_num, page_num)
     |> assign(:taxa, taxa)
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
end
