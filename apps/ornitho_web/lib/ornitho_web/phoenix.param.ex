defimpl Phoenix.Param, for: Ornitho.Schema.Taxon do
  def to_param(taxon), do: taxon.code
end
