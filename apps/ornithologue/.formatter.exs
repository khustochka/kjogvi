# Used by "mix format"
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test,scripts}/**/*.{ex,exs}"],
  import_deps: [:ecto, :ecto_sql],
  subdirectories: ["priv/*/migrations"]
]
