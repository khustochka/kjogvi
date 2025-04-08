defmodule Kjogvi.Ebird.Web.Client.Login do
  @moduledoc """
  eBird login flow.
  """

  alias Kjogvi.Ebird.Web.Client

  @sign_in_link "/home?forceLogin=true"

  @login_form_css "form[action=login]"
  @login_form_fields_to_add [:execution]

  @cas_base_url "https://secure.birds.cornell.edu"
  @cas_form_action "/cassso/login"

  @default_form_details [
    service: "https://ebird.org/login/cas?portal=ebird",
    locale: "en",
    _eventId: "submit"
  ]

  @username_css "nav[aria-labelledby=account-menu-heading] ul.Header-list-list li:first-child span bdo"
  @login_error_css "div#alert-badlogin p"

  @doc """
  Performs login into eBird. Accepts a keyword list that will be submitted through
  the login form. This keyword list should contain 'username', 'password' keys.
  If sucessful, returns the session (cookie jar) that can be used to make further requests.
  """
  @spec login(keyword()) :: {:ok, HttpCookie.Jar.t()} | {:error, any()}
  def login(credentials) do
    cookie_jar = HttpCookie.Jar.new(cookie_opts: [reject_public_suffixes: false])

    case click_sign_in(cookie_jar) do
      {:ok, cookie_jar, form_details} ->
        form_details
        |> Keyword.merge(credentials)
        |> submit_login_form(cookie_jar)

      err ->
        err
    end
  end

  defp click_sign_in(cookie_jar) do
    with {:ok, resp} <- Req.get(Client.req(), url: @sign_in_link, cookie_jar: cookie_jar),
         {:ok, form_details} <- extract_form_details(resp) do
      %{private: %{cookie_jar: cookie_jar}} = resp
      {:ok, cookie_jar, form_details}
    end
  end

  defp submit_login_form(form_details, cookie_jar) do
    with {:ok, resp} <- send_form_request(form_details, cookie_jar),
         :ok <- verify_logged_in(resp, Keyword.get(form_details, :username)) do
      %{private: %{cookie_jar: cookie_jar}} = resp
      {:ok, cookie_jar}
    end
  end

  def extract_form_details(resp) do
    with {:ok, doc} <- Floki.parse_document(resp.body),
         form <- Floki.find(doc, @login_form_css) do
      @login_form_fields_to_add
      |> Enum.reduce([], fn field, acc ->
        Keyword.put(acc, field, extract_form_field(form, field))
      end)
      |> then(&{:ok, &1})
    end
  end

  defp extract_form_field(form, field) do
    Floki.attribute(form, "input[name=#{field}]", "value") |> Floki.text()
  end

  defp send_form_request(form_details, cookie_jar) do
    form_fields =
      @default_form_details
      |> Keyword.merge(form_details)

    Req.new(base_url: @cas_base_url)
    |> HttpCookie.ReqPlugin.attach()
    |> Req.post(
      url: @cas_form_action,
      form: form_fields,
      cookie_jar: cookie_jar
    )
  end

  defp verify_logged_in(resp, username) do
    with {:ok, doc} <- Floki.parse_document(resp.body) do
      case Floki.find(doc, @username_css) do
        [] ->
          read_login_error(doc)

        html ->
          if Regex.match?(~r/.* \(#{username}\)/, Floki.text(html)) do
            :ok
          else
            read_login_error(doc)
          end
      end
    end
  end

  defp read_login_error(doc) do
    case Floki.find(doc, @login_error_css) do
      [] -> {:error, "Login failed."}
      div -> {:error, "Login failed: #{Floki.text(div)}."}
    end
  end
end
