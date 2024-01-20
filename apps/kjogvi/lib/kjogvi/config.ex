defmodule Kjogvi.Config do
  def allow_user_registration do
    Application.get_env(:kjogvi, :allow_user_registration, false)
  end
end
