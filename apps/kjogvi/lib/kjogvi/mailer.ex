defmodule Kjogvi.Mailer do
  @moduledoc false

  use Swoosh.Mailer, otp_app: :kjogvi

  def registration_sender do
    Application.get_env(:kjogvi, :email)[:registration_sender]
  end
end
