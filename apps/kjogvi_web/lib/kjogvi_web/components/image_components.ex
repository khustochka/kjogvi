defmodule KjogviWeb.ImageComponents do
  @moduledoc """
  Components for the image upload UI, shared between the add-image and
  replace-file flows.
  """

  use Phoenix.Component
  use Phoenix.VerifiedRoutes, endpoint: KjogviWeb.Endpoint, router: KjogviWeb.Router

  import KjogviWeb.IconComponents

  alias KjogviWeb.CoreComponents

  @doc """
  The editable metadata fields shared by the add-image and edit-image forms:
  slug, title, description, and sort order. The enclosing `<.form>` and submit
  buttons are the caller's responsibility.
  """
  attr :form, Phoenix.HTML.Form, required: true

  def image_metadata_fields(assigns) do
    ~H"""
    <CoreComponents.input field={@form[:slug]} label="Slug" required />
    <CoreComponents.input field={@form[:title]} label="Title" />
    <CoreComponents.input field={@form[:description]} type="textarea" label="Description" />
    <div class="w-32">
      <CoreComponents.input field={@form[:sort_order]} type="number" label="Sort order" min="0" />
    </div>
    """
  end

  @doc """
  A single observation rendered as a tile: taxon name, card date, and location.

  Used both for the observations already attached/selected on an image and for
  the search-result rows in the observation picker. When an `on_remove` event is
  given, an × button is shown that pushes it with `phx-value-observation-id`.
  When an `on_add` event is given (search results), a + button is shown instead.
  """
  attr :observation, :map, required: true
  attr :on_remove, :string, default: nil, doc: "event pushed by the × button"
  attr :on_add, :string, default: nil, doc: "event pushed by the + button"
  attr :target, :any, default: nil, doc: "phx-target for the add/remove events"
  attr :rest, :global

  def observation_tile(assigns) do
    ~H"""
    <div
      class="flex items-center justify-between gap-2 rounded-lg border border-stone-200 bg-white px-3 py-2 text-sm"
      {@rest}
    >
      <div class="min-w-0">
        <div class="truncate font-medium text-stone-800">{taxon_name(@observation)}</div>
        <div class="text-xs text-stone-500">
          {@observation.card.observ_date}
          <span :if={@observation.card.location} class="text-stone-400">
            · {@observation.card.location.name_en}
          </span>
        </div>
      </div>

      <button
        :if={@on_add}
        type="button"
        phx-click={@on_add}
        phx-target={@target}
        phx-value-observation-id={@observation.id}
        aria-label="Attach observation"
        title="Attach observation"
        class="shrink-0 rounded-md bg-green-100 p-1 text-green-700 hover:bg-green-200"
      >
        <.icon name="hero-plus" class="w-4 h-4" />
      </button>

      <button
        :if={@on_remove}
        type="button"
        phx-click={@on_remove}
        phx-target={@target}
        phx-value-observation-id={@observation.id}
        aria-label="Remove observation"
        title="Remove observation"
        class="shrink-0 rounded-md bg-rose-100 p-1 text-rose-700 hover:bg-rose-200"
      >
        <.icon name="hero-x-mark" class="w-4 h-4" />
      </button>
    </div>
    """
  end

  defp taxon_name(%{taxon: %{name_en: name_en}}) when is_binary(name_en), do: name_en
  defp taxon_name(%{taxon_key: key}) when is_binary(key), do: key
  defp taxon_name(_), do: "Unknown taxon"

  @doc """
  A drag-and-drop file upload zone with an inline preview.

  Wraps a single `Phoenix.LiveView.UploadConfig` (passed as `upload`). When no
  file has finished uploading it shows the choose/drop prompt; once `uploaded?`
  is true it shows a preview of the entry plus its name and size and a label to
  pick a different file. The hosting `<form>` and its submit buttons are the
  caller's responsibility — this renders only the drop zone.
  """
  attr :id, :string, required: true, doc: "DOM id for the drop zone container"
  attr :upload, :any, required: true, doc: "the @uploads.<name> UploadConfig"
  attr :uploaded?, :boolean, required: true, doc: "whether a file has finished uploading"
  attr :client_name, :string, default: nil, doc: "the uploaded file's name"
  attr :client_size, :integer, default: nil, doc: "the uploaded file's size in bytes"

  attr :preview_label, :string,
    default: "Replace image",
    doc: "the label under the preview to pick a different file"

  attr :client_preview?, :boolean,
    default: false,
    doc: """
    when true, the preview is rendered from a browser-held `blob:` URL via the
    `ImageUploadPreview` JS hook instead of `live_img_preview` — used after the
    entry has been consumed early (e.g. to read EXIF), which empties
    `@upload.entries` and removes `live_img_preview`.
    """

  def image_drop_zone(assigns) do
    ~H"""
    <div
      id={@id}
      phx-drop-target={@upload.ref}
      phx-hook={@client_preview? && "ImageUploadPreview"}
      class={[
        "border-2 border-dashed rounded-xl p-8 text-center transition-colors",
        if(@uploaded?,
          do: "border-forest-400 bg-forest-50",
          else: "border-stone-300 bg-stone-50 hover:border-forest-400"
        )
      ]}
    >
      <.live_file_input upload={@upload} class="sr-only" />

      <div :if={@uploaded?} class="flex flex-col items-center gap-3">
        <img
          :if={@client_preview?}
          data-role="client-preview"
          alt={@client_name}
          class="max-h-48 max-w-full rounded-lg object-contain shadow"
        />
        <.live_img_preview
          :for={entry <- @upload.entries}
          :if={not @client_preview?}
          entry={entry}
          class="max-h-48 max-w-full rounded-lg object-contain shadow"
        />
        <div class="text-sm text-stone-600">
          {@client_name}
          <span :if={@client_size} class="text-stone-400 ml-1">
            ({format_bytes(@client_size)})
          </span>
        </div>
        <label for={@upload.ref} class="cursor-pointer text-forest-600 hover:underline text-sm">
          {@preview_label}
        </label>
      </div>

      <div :if={not @uploaded?} class="flex flex-col items-center gap-3 text-stone-500">
        <.icon name="hero-photo" class="w-12 h-12 text-stone-400" />
        <div>
          <label for={@upload.ref} class="cursor-pointer text-forest-600 hover:underline">
            Choose a file
          </label>
          or drag and drop here
        </div>
        <div class="text-xs text-stone-400">JPEG, PNG, WebP, TIFF, HEIC — max 50 MB</div>
      </div>

      <div :for={entry <- @upload.entries}>
        <div :if={not entry.done? and entry.progress > 0} class="mt-3">
          <div class="w-full bg-stone-200 rounded-full h-2">
            <div
              class="bg-forest-500 h-2 rounded-full transition-all"
              style={"width: #{entry.progress}%"}
            >
            </div>
          </div>
          <p class="text-xs text-stone-500 mt-1">{entry.progress}%</p>
        </div>

        <p :for={err <- upload_errors(@upload, entry)} class="text-rose-600 text-sm mt-2">
          {upload_error_to_string(err)}
        </p>
      </div>

      <p :for={err <- upload_errors(@upload)} class="text-rose-600 text-sm mt-2">
        {upload_error_to_string(err)}
      </p>
    </div>
    """
  end

  defp format_bytes(bytes) when bytes < 1_024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1_024 * 1_024, do: "#{div(bytes, 1_024)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / (1_024 * 1_024), 1)} MB"

  defp upload_error_to_string(:too_large), do: "File is too large (max 50 MB)"
  defp upload_error_to_string(:not_accepted), do: "File type not accepted"
  defp upload_error_to_string(:too_many_files), do: "Only one file allowed"
  defp upload_error_to_string(_), do: "Upload error"
end
