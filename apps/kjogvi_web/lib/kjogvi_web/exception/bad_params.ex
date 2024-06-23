defmodule KjogviWeb.Exception.BadParams do
  defexception message: "Bad parameters."
end

defimpl Plug.Exception, for: KjogviWeb.Exception.BadParams do
  def status(_), do: 400
  def actions(_), do: []
end
