defmodule KjogviWeb.Live.My.Settings.Profile do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Accounts
  alias Kjogvi.Accounts.Avatar
  alias Kjogvi.Geo
  alias Kjogvi.Images

  @avatar_max_file_size 20 * 1_024 * 1_024

  # Generic message for a failed avatar upload; the detail is logged
  # server-side.
  @avatar_storage_failed_message "Could not upload the avatar. Please try again later."

  def render(assigns) do
    ~H"""
    <.h1>Account Settings</.h1>

    <.account_settings active={:profile}>
      <.h2>Profile</.h2>

      <section class="mt-8">
        <h3 class="block text-sm font-semibold leading-6 text-zinc-800">Avatar</h3>

        <div class="mt-2 flex flex-col gap-4 sm:flex-row sm:items-start">
          <div class="flex h-32 w-32 shrink-0 items-center justify-center border border-zinc-200 bg-zinc-50">
            <img
              :if={@avatar_url}
              id="avatar-preview"
              src={@avatar_url}
              alt="Your avatar"
              class="max-h-full max-w-full"
            />
            <span :if={!@avatar_url} id="avatar-placeholder" class="text-sm text-zinc-400">
              No avatar
            </span>
          </div>

          <div class="space-y-2">
            <.form for={%{}} id="avatar_form" phx-change="validate_avatar">
              <div
                phx-drop-target={@uploads.avatar.ref}
                class={[
                  "rounded-lg border-2 border-dashed border-stone-300 bg-stone-50 px-4 py-3",
                  "text-sm text-stone-500 hover:border-forest-400",
                  "[&.phx-drop-target-active]:border-forest-500 [&.phx-drop-target-active]:bg-forest-100"
                ]}
              >
                <.live_file_input upload={@uploads.avatar} class="sr-only" />
                <label
                  for={@uploads.avatar.ref}
                  class="cursor-pointer font-semibold text-forest-600 hover:underline"
                >Choose a file</label>
                or drag and drop here
              </div>
            </.form>

            <p class="text-sm text-zinc-500">
              JPEG, PNG or WebP, up to 20 MB. Displayed at up to 512×512 pixels.
            </p>

            <div :for={entry <- @uploads.avatar.entries}>
              <p :if={not entry.done? and entry.progress > 0} class="text-sm text-zinc-500">
                Uploading… {entry.progress}%
              </p>
              <p :for={err <- upload_errors(@uploads.avatar, entry)} class="text-sm text-rose-600">
                {avatar_upload_error(err)}
              </p>
            </div>

            <p :for={err <- upload_errors(@uploads.avatar)} class="text-sm text-rose-600">
              {avatar_upload_error(err)}
            </p>

            <.button
              :if={@avatar_url}
              id="remove-avatar"
              variant="danger"
              phx-click="remove_avatar"
              data-confirm="Remove your avatar?"
            >
              Remove avatar
            </.button>
          </div>
        </div>
      </section>

      <.form
        for={@settings_form}
        id="settings_form"
        phx-change="validate_settings"
        phx-submit="update_settings"
      >
        <div class="mt-8 space-y-8 bg-white">
          <CoreComponents.input
            field={@settings_form[:nickname]}
            type="text"
            label="Nickname"
            required
          >
            <:hint>3–20 characters: lowercase letters, digits, hyphens and underscores.</:hint>
          </CoreComponents.input>

          <CoreComponents.input
            field={@settings_form[:display_name]}
            type="text"
            label="Display name"
          >
            <:hint>Up to 50 characters: letters, spaces and common punctuation.</:hint>
          </CoreComponents.input>

          <.inputs_for :let={profile_form} field={@settings_form[:profile]}>
            <CoreComponents.input
              field={profile_form[:about]}
              type="textarea"
              label="About"
              rows="4"
            >
              <:hint>A short description of yourself. Up to 2000 characters.</:hint>
            </CoreComponents.input>

            <CoreComponents.input
              field={profile_form[:country]}
              type="select"
              label="Country"
              options={@country_options}
              prompt="Select country..."
            />

            <CoreComponents.input
              field={profile_form[:ebird_profile_url]}
              type="url"
              label="eBird profile URL"
            >
              <:hint>Link to your public eBird profile.</:hint>
            </CoreComponents.input>

            <CoreComponents.input
              field={profile_form[:website_url]}
              type="url"
              label="Website URL"
            />
          </.inputs_for>

          <div class="mt-2 flex items-center justify-between gap-6">
            <.button phx-disable-with="Saving...">
              Update
            </.button>
          </div>
        </div>
      </.form>
    </.account_settings>
    """
  end

  def mount(_params, _session, %{assigns: %{live_action: :redirect}} = socket) do
    {:ok, push_navigate(socket, to: ~p"/my/settings/profile")}
  end

  def mount(_params, _session, socket) do
    # Preload :profile so `inputs_for @settings_form[:profile]` can render.
    user = Accounts.preload_profile(socket.assigns.current_scope.current_user)
    settings_changeset = Accounts.User.profile_settings_changeset(user, %{})

    socket =
      socket
      |> assign(:page_title, "Profile")
      |> assign(:user, user)
      |> assign(:country_options, country_options())
      |> assign(:settings_form, to_form(settings_changeset))
      |> assign(:avatar_url, Images.avatar_url(user.profile))
      |> allow_upload(:avatar,
        accept: Images.Uploader.accepted_extensions(),
        max_entries: 1,
        max_file_size: @avatar_max_file_size,
        auto_upload: true,
        progress: &handle_avatar_progress/3
      )

    {:ok, socket}
  end

  def handle_event("validate_avatar", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("remove_avatar", _params, socket) do
    case Avatar.remove(socket.assigns.user) do
      {:ok, profile} ->
        {:noreply,
         socket
         |> assign_avatar(profile)
         |> put_flash(:info, "Avatar removed.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not remove the avatar.")}
    end
  end

  def handle_event("validate_settings", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.user
      |> Accounts.User.profile_settings_changeset(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :settings_form, to_form(changeset))}
  end

  def handle_event("update_settings", %{"user" => user_params}, socket) do
    case Accounts.update_user_profile_settings(socket.assigns.user, user_params) do
      {:ok, user} ->
        settings_form =
          user
          |> Accounts.User.profile_settings_changeset(%{})
          |> to_form()

        scope = %{socket.assigns.current_scope | current_user: user}

        socket =
          socket
          |> put_flash(:info, "User account updated.")
          |> assign(:current_scope, scope)
          |> assign(:user, user)
          |> assign(:settings_form, settings_form)

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, settings_form: to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  defp handle_avatar_progress(:avatar, entry, socket) do
    if entry.done? do
      result =
        consume_uploaded_entry(socket, entry, fn %{path: path} ->
          upload = %Plug.Upload{
            path: path,
            filename: entry.client_name,
            content_type: entry.client_type
          }

          {:ok, Avatar.update(socket.assigns.user, upload)}
        end)

      case result do
        {:ok, profile} ->
          {:noreply,
           socket
           |> assign_avatar(profile)
           |> put_flash(:info, "Avatar updated.")}

        {:error, :storage_failed} ->
          {:noreply, put_flash(socket, :error, @avatar_storage_failed_message)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not update the avatar.")}
      end
    else
      {:noreply, socket}
    end
  end

  # Keeps `@user.profile` in sync with the row the avatar operation touched,
  # so a subsequent profile form submit updates that row rather than trying to
  # insert a second one.
  defp assign_avatar(socket, profile) do
    profile = if profile.id, do: profile, else: nil
    user = %{socket.assigns.user | profile: profile}

    socket
    |> assign(:user, user)
    |> assign(:avatar_url, Images.avatar_url(profile))
  end

  defp avatar_upload_error(:too_large), do: "File is too large (max 20 MB)"
  defp avatar_upload_error(:not_accepted), do: "File type not accepted"
  defp avatar_upload_error(:too_many_files), do: "Only one file allowed"
  defp avatar_upload_error(_), do: "Upload error"

  defp country_options do
    Enum.map(Geo.list_common_countries(), &{&1.name_en, &1.iso_code})
  end
end
