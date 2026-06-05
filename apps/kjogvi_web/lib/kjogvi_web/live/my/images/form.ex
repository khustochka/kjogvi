defmodule KjogviWeb.Live.My.Images.Form do
  @moduledoc """
  Create a new image or edit an existing one. The same form serves both the
  `:new` and `:edit` live actions, branching on `@live_action`.

  ## New

  The file is auto-uploaded on drop/select; a thumbnail preview then appears and
  can be replaced. The slug is prefilled from the file name and the rest of the
  metadata form (title, description, sort order) is filled in before saving.
  Until a file is uploaded the metadata form is hidden — the upload gates it.

  ## Edit

  The metadata form is shown immediately, prefilled from the image, and saves on
  the main "Save Changes" button. Replacing the stored file is a separate,
  optional sub-flow: the "Replace file" button reveals the drop zone, where a new
  file auto-uploads and can be applied on its own with "Replace File". If a file
  is staged there but the user clicks the main "Save Changes" instead, the staged
  file is applied as part of that save so it is never silently dropped (see
  `Kjogvi.Images.replace_image_file/2`).

  ## Shared upload handling

  In both actions the finished upload is consumed to a stable `Plug.Upload` on
  progress (not at save). For `:new` this lets its EXIF date seed the observation
  picker before save; for `:edit` it stages the replacement on a path waffle can
  still read at save time. The browser-rendered preview does not depend on the
  server entry, so consuming early is safe.

  Observations are attached via the shared `ImageObservations` picker; the
  selection is staged in `selected_observation_ids` and linked/persisted on save.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Images
  alias Kjogvi.Images.Image
  alias Kjogvi.Repo
  # CoreComponents.input is used explicitly for the metadata fields: the
  # ambient <.input> imported into LiveViews is FormComponents.input, which only
  # handles password inputs and would not render plain text/textarea/number.
  alias KjogviWeb.CoreComponents
  alias KjogviWeb.Live.Components.ImageObservations

  # 50 MB.
  @max_file_size 50 * 1_024 * 1_024
  @accept ~w(.jpg .jpeg .png .webp .tiff .tif .heic .heif)

  # Temporary product rule: an image must be linked to at least one observation
  # (also enforced by `Image.observations_changeset/2`). Remove this guard when
  # standalone images are allowed.
  @no_observations_message "Please attach at least one observation."

  # Shown when staged observations can't be linked at all (foreign ids, or ids
  # spanning different cards) — normally unreachable through the picker UI, so
  # this is the backstop for a tampered request.
  @observations_invalid_message "Those observations couldn't be attached. They must be your own and from a single card."

  @impl true
  def mount(params, _session, socket) do
    socket
    |> assign(:uploaded?, false)
    |> assign(:client_name, nil)
    |> assign(:client_size, nil)
    # The finished upload, consumed to a stable Plug.Upload on progress so its
    # EXIF date can be read before save and so it survives until save; reused as
    # the file at save time.
    |> assign(:upload, nil)
    |> assign(:selected_observation_ids, [])
    |> assign(:selected_observations, [])
    |> mount_action(socket.assigns.live_action, params)
    |> allow_upload(:image,
      accept: @accept,
      max_entries: 1,
      max_file_size: @max_file_size,
      auto_upload: true,
      progress: &handle_progress/3
    )
    |> then(&{:ok, &1})
  end

  defp mount_action(socket, :new, _params) do
    user = socket.assigns.current_scope.user

    socket
    |> assign(:page_title, "Add Image")
    |> assign(:image, nil)
    # In :new the drop zone is the gate, always present, so there is no separate
    # "replacing" toggle.
    |> assign(:replacing?, true)
    # Until a file is uploaded there is no EXIF date, so seed the picker with the
    # user's most recent card date; the EXIF date replaces it on upload.
    |> assign(:observation_date, Kjogvi.Birding.last_card_date(user))
    |> assign_form(%{"sort_order" => 100})
  end

  defp mount_action(socket, :edit, %{"id" => id}) do
    user = socket.assigns.current_scope.user
    image = user |> Images.get_image!(id) |> Repo.preload(:observations)

    ids = Enum.map(image.observations, & &1.id)
    selected = Images.get_observations_for_display(user, ids)

    socket
    |> assign(:page_title, "Edit Image")
    |> assign(:image, image)
    # The drop zone is hidden behind the "Replace file" button.
    |> assign(:replacing?, false)
    |> assign(:selected_observation_ids, Enum.map(selected, & &1.id))
    |> assign(:selected_observations, selected)
    |> assign(:observation_date, default_observation_date(user, image, selected))
    |> assign(:form, to_form(Images.change_image(image)))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <nav :if={@live_action == :edit} id="image-breadcrumbs" class="text-sm text-stone-500">
        <.breadcrumb_link href={~p"/my/images"}>Images</.breadcrumb_link>
        <span class="mx-1 text-stone-400">/</span>
        <.breadcrumb_link href={~p"/my/images/#{@image.id}"} phx-no-format>{@image.title || @image.slug}</.breadcrumb_link>
        <span class="mx-1 text-stone-400">/</span>
        <span class="text-stone-700">Edit</span>
      </nav>

      <.h1>{@page_title}</.h1>

      <%!-- Edit-only: the current image with a button to reveal the replace
            drop zone, and the standalone replace sub-form. --%>
      <div :if={@live_action == :edit} class="space-y-4">
        <div
          :if={not @replacing?}
          id="current-image-panel"
          class="flex flex-col items-center gap-3 rounded-xl border border-stone-200 bg-stone-50 p-6"
        >
          <img
            src={Images.url(@image, :medium)}
            alt={@image.title || @image.slug}
            class="max-h-72 max-w-full rounded-lg object-contain shadow"
          />

          <button
            id="replace-file-button"
            type="button"
            phx-click="start_replace"
            class="inline-flex items-center gap-2 text-sm text-forest-600 hover:underline"
          >
            <.icon name="hero-arrow-path" class="w-4 h-4" /> Replace file
          </button>
        </div>

        <form
          :if={@replacing?}
          id="replace-file-form"
          phx-submit="replace"
          phx-change="validate_upload"
          class="space-y-4"
        >
          <.image_drop_zone
            id="replace-drop-zone"
            upload={@uploads.image}
            uploaded?={@uploaded?}
            client_name={@client_name}
            client_size={@client_size}
            client_preview?={true}
          />

          <div class="flex gap-4">
            <button
              type="submit"
              disabled={not @uploaded?}
              phx-disable-with="Replacing..."
              class="inline-flex items-center gap-2 rounded-lg bg-green-600 px-6 py-2 text-sm font-semibold text-white hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Replace File
            </button>
            <button
              type="button"
              phx-click="cancel_replace"
              class="inline-flex items-center rounded-lg border border-red-300 px-4 py-2 text-sm font-semibold text-red-700 hover:bg-red-50"
            >
              Cancel
            </button>
          </div>
        </form>
      </div>

      <.form for={@form} id="image-form" phx-submit="save" phx-change="validate" class="space-y-6">
        <%!-- New-only: the drop zone gates the rest of the form. --%>
        <.image_drop_zone
          :if={@live_action == :new}
          id="upload-drop-zone"
          upload={@uploads.image}
          uploaded?={@uploaded?}
          client_name={@client_name}
          client_size={@client_size}
          client_preview?={true}
        />

        <div :if={@live_action == :edit or @uploaded?} class="space-y-4">
          <CoreComponents.input field={@form[:slug]} label="Slug" required />
          <CoreComponents.input field={@form[:title]} label="Title" />
          <CoreComponents.input field={@form[:description]} type="textarea" label="Description" />
          <div class="w-32">
            <CoreComponents.input field={@form[:sort_order]} type="number" label="Sort order" min="0" />
          </div>

          <.live_component
            module={ImageObservations}
            id="image-observations"
            current_user={@current_scope.user}
            date={@observation_date}
            selected={@selected_observations}
          />

          <div class="space-y-2 pt-2 border-t border-stone-200">
            <p
              :if={@live_action == :edit and @replacing? and @uploaded?}
              id="save-replaces-file-hint"
              class="text-sm text-red-600"
            >
              Saving will also replace the image file.
            </p>

            <div class="flex gap-4">
              <button
                type="submit"
                phx-disable-with="Saving..."
                class="inline-flex items-center gap-2 rounded-lg bg-green-600 px-6 py-2 text-sm font-semibold text-white hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {if @live_action == :new, do: "Save Image", else: "Save Changes"}
              </button>
              <.action_button navigate={cancel_path(@live_action, @image)} variant="secondary">
                Cancel
              </.action_button>
            </div>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  defp cancel_path(:new, _image), do: ~p"/my/images"
  defp cancel_path(:edit, image), do: ~p"/my/images/#{image.id}"

  defp handle_progress(:image, entry, socket) do
    # Consume the entry now (not at save) so the file is on a stable path: for
    # :new so its EXIF date can seed the observation picker, for :edit so it
    # survives as the staged replacement until save. The browser-rendered preview
    # doesn't depend on the server entry, so consuming here is safe.
    with true <- entry.done?,
         {:ok, plug_upload} <- consume_upload(socket) do
      {:noreply,
       socket
       |> stash_upload(plug_upload)
       |> assign(:uploaded?, true)
       |> assign(:client_name, entry.client_name)
       |> assign(:client_size, entry.client_size)
       |> maybe_prefill_from_exif(entry, plug_upload)}
    else
      _ -> {:noreply, socket}
    end
  end

  # After a file lands, seed two things from it:
  #
  #   * The observation-picker date, from the file's EXIF capture date — but only
  #     when no observations are selected yet, so we never override a date the
  #     user (or the existing links) already pinned the search to. Applies to
  #     both :new and :edit.
  #   * The slug, from the file name — only on :new (on :edit the slug is the
  #     stored one and must not be clobbered by a replacement file's name). On
  #     :new the slug always tracks the latest file, including on a re-pick.
  defp maybe_prefill_from_exif(socket, entry, plug_upload) do
    socket
    |> maybe_prefill_observation_date(plug_upload)
    |> maybe_prefill_slug(entry.client_name)
  end

  defp maybe_prefill_observation_date(
         %{assigns: %{selected_observation_ids: [_ | _]}} = socket,
         _plug_upload
       ) do
    socket
  end

  defp maybe_prefill_observation_date(socket, plug_upload) do
    assign(socket, :observation_date, observation_date(socket, plug_upload))
  end

  defp maybe_prefill_slug(%{assigns: %{live_action: :new}} = socket, client_name) do
    params =
      socket
      |> current_params()
      |> Map.put("slug", slugify(client_name))

    assign_form(socket, params)
  end

  defp maybe_prefill_slug(socket, _client_name), do: socket

  # Prefer the uploaded file's EXIF capture date; fall back to the date the
  # picker was already seeded with when the file carries no EXIF date.
  defp observation_date(socket, plug_upload) do
    Images.exif_date_from_upload(plug_upload) || socket.assigns.observation_date
  end

  # Replace any previously stashed upload, removing its temp file first so a
  # re-pick doesn't leak the prior file.
  defp stash_upload(socket, plug_upload) do
    discard_stash(socket)
    assign(socket, :upload, plug_upload)
  end

  # Remove the stashed temp file, if any.
  defp discard_stash(socket) do
    case socket.assigns[:upload] do
      %Plug.Upload{path: path} -> File.rm(path)
      _ -> :ok
    end
  end

  @impl true
  def handle_event("start_replace", _params, socket) do
    {:noreply, assign(socket, :replacing?, true)}
  end

  def handle_event("cancel_replace", _params, socket) do
    socket =
      Enum.reduce(socket.assigns.uploads.image.entries, socket, fn entry, socket ->
        cancel_upload(socket, :image, entry.ref)
      end)

    discard_stash(socket)

    {:noreply,
     socket
     |> assign(:replacing?, false)
     |> assign(:uploaded?, false)
     |> assign(:upload, nil)
     |> assign(:client_name, nil)
     |> assign(:client_size, nil)}
  end

  def handle_event("validate_upload", _params, socket) do
    # The auto-uploading file input fires phx-change; nothing to validate here,
    # the upload macro handles entry errors on its own.
    {:noreply, socket}
  end

  def handle_event("validate", params, socket) do
    # The file input shares this form, so `validate` also fires on upload
    # changes — before the metadata fields exist (in :new) there is no "image"
    # key.
    {:noreply, assign_form(socket, params["image"] || %{}, :validate)}
  end

  def handle_event("replace", _params, socket) do
    case socket.assigns.upload do
      %Plug.Upload{} = plug_upload ->
        result = Images.replace_image_file(socket.assigns.image, %{"file" => plug_upload})
        discard_stash(socket)

        case result do
          {:ok, image} ->
            {:noreply,
             socket
             |> assign(:upload, nil)
             |> put_flash(:info, "Image file replaced")
             |> push_navigate(to: ~p"/my/images/#{image.id}")}

          {:error, %Ecto.Changeset{}} ->
            {:noreply, put_flash(socket, :error, "Could not replace the image file")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Please choose a file to upload")}
    end
  end

  def handle_event("save", params, socket) do
    save(socket, socket.assigns.live_action, params)
  end

  defp save(socket, :new, %{"image" => params}) do
    user = socket.assigns.current_scope.user

    cond do
      not match?(%Plug.Upload{}, socket.assigns.upload) ->
        {:noreply, put_flash(socket, :error, "Please choose a file to upload")}

      socket.assigns.selected_observation_ids == [] ->
        {:noreply, put_flash(socket, :error, @no_observations_message)}

      true ->
        plug_upload = socket.assigns.upload
        attrs = Map.put(params, "file", plug_upload)

        case Images.create_image(user, attrs) do
          {:ok, image} ->
            case Images.attach_observations(image, socket.assigns.selected_observation_ids) do
              {:ok, _image} ->
                discard_stash(socket)

                {:noreply,
                 socket
                 |> assign(:upload, nil)
                 |> put_flash(:info, "Image uploaded")
                 |> push_navigate(to: ~p"/my/images/#{image.id}")}

              {:error, %Ecto.Changeset{}} ->
                # The observations couldn't be linked (e.g. a tampered request
                # with foreign or cross-card ids). Don't leave an orphan image
                # behind — it's invalid without observations — and report it.
                Images.delete_image(image)

                {:noreply, put_flash(socket, :error, @observations_invalid_message)}
            end

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset))}
        end
    end
  end

  defp save(socket, :edit, %{"image" => params}) do
    if socket.assigns.selected_observation_ids == [] do
      {:noreply, put_flash(socket, :error, @no_observations_message)}
    else
      case Images.update_image(socket.assigns.image, params) do
        {:ok, image} ->
          case Images.attach_observations(image, socket.assigns.selected_observation_ids) do
            {:ok, _image} ->
              {:noreply, maybe_replace_then_navigate(socket, image)}

            {:error, %Ecto.Changeset{}} ->
              # Metadata was saved, but the observations couldn't be linked (e.g.
              # a tampered request with foreign or cross-card ids). The existing
              # links are left untouched; report it and stay on the form.
              {:noreply, put_flash(socket, :error, @observations_invalid_message)}
          end

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, :form, to_form(changeset))}
      end
    end
  end

  # When the replace sub-form is open with a staged file, the main save also
  # applies it so a pending file isn't silently dropped. The metadata save above
  # already succeeded; if replacing the file then fails, fall back to the plain
  # "updated" message rather than failing the whole save.
  defp maybe_replace_then_navigate(socket, image) do
    case socket.assigns.upload do
      %Plug.Upload{} = plug_upload when socket.assigns.replacing? ->
        result = Images.replace_image_file(image, %{"file" => plug_upload})
        discard_stash(socket)

        case result do
          {:ok, replaced} ->
            socket
            |> assign(:upload, nil)
            |> put_flash(:info, "Image and file updated")
            |> push_navigate(to: ~p"/my/images/#{replaced.id}")

          {:error, %Ecto.Changeset{}} ->
            socket
            |> assign(:upload, nil)
            |> put_flash(:info, "Image updated, but the file could not be replaced")
            |> push_navigate(to: ~p"/my/images/#{image.id}")
        end

      _ ->
        socket
        |> put_flash(:info, "Image updated")
        |> push_navigate(to: ~p"/my/images/#{image.id}")
    end
  end

  @impl true
  def handle_info({:image_observations_changed, ids}, socket) do
    user = socket.assigns.current_scope.user

    {:noreply,
     socket
     |> assign(:selected_observation_ids, ids)
     |> assign(:selected_observations, Images.get_observations_for_display(user, ids))}
  end

  @impl true
  def terminate(_reason, socket) do
    # Drop the stashed temp file if the user navigated away without saving.
    discard_stash(socket)
  end

  # The observation search defaults to the date of the already-attached
  # observations; failing that, the image's EXIF capture date; failing that, the
  # user's most recent card date.
  defp default_observation_date(_user, _image, [%{card: %{observ_date: %Date{} = date}} | _]) do
    date
  end

  defp default_observation_date(user, image, []) do
    case Image.exif_date(image) do
      %NaiveDateTime{} = naive -> NaiveDateTime.to_date(naive)
      _ -> Kjogvi.Birding.last_card_date(user)
    end
  end

  # Consume the single uploaded entry into a persistent Plug.Upload. The
  # LiveView temp file is deleted as soon as the callback returns, so copy it to
  # a path waffle can still read during create_image/2 or replace_image_file/2.
  defp consume_upload(socket) do
    socket
    |> consume_uploaded_entries(:image, fn %{path: path}, entry ->
      ext = Path.extname(entry.client_name)
      dest = Waffle.File.generate_temporary_path(ext)
      File.cp!(path, dest)

      {:ok,
       %Plug.Upload{
         path: dest,
         filename: entry.client_name,
         content_type: entry.client_type || "application/octet-stream"
       }}
    end)
    |> case do
      [plug_upload] -> {:ok, plug_upload}
      [] -> :error
    end
  end

  defp assign_form(socket, params, action \\ nil) do
    # In :edit the changeset is based on the loaded image (so e.g. slug
    # uniqueness validates against the existing record); in :new on a blank
    # struct.
    changeset =
      (socket.assigns[:image] || %Image{})
      |> Images.change_image(params)
      |> maybe_put_action(action)

    assign(socket, :form, to_form(changeset))
  end

  defp maybe_put_action(changeset, nil), do: changeset
  defp maybe_put_action(changeset, action), do: Map.put(changeset, :action, action)

  defp current_params(%{assigns: %{form: %Phoenix.HTML.Form{params: params}}})
       when is_map(params),
       do: params

  defp current_params(_), do: %{}

  defp slugify(filename) do
    filename
    |> Path.basename(Path.extname(filename))
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end
end
