defimpl Phoenix.Param, for: Kjogvi.Geo.Location do
  def to_param(loc), do: loc.slug
end

defimpl Phoenix.Param, for: Kjogvi.Pages.Species do
  def to_param(species) do
    species.name_sci
    |> String.replace(" ", "_", global: false)
  end
end

defimpl Phoenix.Param, for: Kjogvi.Media.Image do
  def to_param(image), do: image.slug
end
