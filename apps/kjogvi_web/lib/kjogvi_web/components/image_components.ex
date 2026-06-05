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
        <div class="truncate font-medium text-stone-800">
          {taxon_name(@observation)}
          <em :if={sci_name(@observation)} class="font-normal text-stone-500">
            {sci_name(@observation)}
          </em>
        </div>
        <div class="text-xs text-stone-500">
          <span class="text-stone-400">#{@observation.card.id}</span>
          · {@observation.card.observ_date}
          <span :if={@observation.card.location} class="text-stone-400">
            · {@observation.card.location.name_en}
          </span>
        </div>
        <div :if={effort_parts(@observation.card) != []} class="text-xs text-stone-500">
          {Enum.join(effort_parts(@observation.card), " · ")}
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
        class="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-green-500 text-white hover:bg-green-600"
      >
        <.icon name="hero-plus" class="h-4 w-4" />
      </button>

      <button
        :if={@on_remove}
        type="button"
        phx-click={@on_remove}
        phx-target={@target}
        phx-value-observation-id={@observation.id}
        aria-label="Remove observation"
        title="Remove observation"
        class="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-red-500 text-white hover:bg-red-600"
      >
        <.icon name="hero-x-mark" class="h-4 w-4" />
      </button>
    </div>
    """
  end

  defp taxon_name(%{taxon: %{name_en: name_en}}) when is_binary(name_en), do: name_en
  defp taxon_name(%{taxon_key: key}) when is_binary(key), do: key
  defp taxon_name(_), do: "Unknown taxon"

  defp sci_name(%{taxon: %{name_sci: name_sci}}) when is_binary(name_sci), do: name_sci
  defp sci_name(_), do: nil

  # The effort attributes available on the card, formatted for the tile's effort
  # line. Each is included only when present, so an INCIDENTAL card with no
  # timing shows just its effort type (or nothing).
  defp effort_parts(card) do
    [
      card.effort_type,
      format_time(card.start_time),
      format_duration(card.duration_minutes),
      format_distance(card.distance_kms),
      format_area(card.area_acres)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp format_time(%Time{} = time), do: Calendar.strftime(time, "%H:%M")
  defp format_time(_), do: nil

  defp format_duration(minutes) when is_integer(minutes) and minutes > 0, do: "#{minutes} min"
  defp format_duration(_), do: nil

  defp format_distance(kms) when is_number(kms) and kms > 0, do: "#{trim_float(kms)} km"
  defp format_distance(_), do: nil

  defp format_area(acres) when is_number(acres) and acres > 0, do: "#{trim_float(acres)} ac"
  defp format_area(_), do: nil

  # Drop a trailing ".0" so whole numbers read cleanly (e.g. "5 km", not "5.0").
  defp trim_float(value) do
    float = value / 1
    if float == Float.round(float), do: trunc(float), else: float
  end

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
