defimpl Phoenix.Param, for: Kjogvi.Geo.Location do
  def to_param(loc), do: loc.slug
end
