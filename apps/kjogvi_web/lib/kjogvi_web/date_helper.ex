defmodule KjogviWeb.DateHelper do
  @moduledoc """
  Helpers for date formatting.
  """

  @month_names {"January", "February", "March", "April", "May", "June", "July", "August",
                "September", "October", "November", "December"}

  @short_month_names {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov",
                      "Dec"}

  def month_name(month_num) do
    @month_names |> elem(month_num - 1)
  end

  def short_month_name(month_num) do
    @short_month_names |> elem(month_num - 1)
  end
end
