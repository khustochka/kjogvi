defmodule KjogviWeb.ImageComponents do
  @moduledoc """
  Components for the image upload UI, shared between the add-image and
  replace-file flows.
  """

  use Phoenix.Component
  use Phoenix.VerifiedRoutes, endpoint: KjogviWeb.Endpoint, router: KjogviWeb.Router

  import KjogviWeb.IconComponents

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

  def image_drop_zone(assigns) do
    ~H"""
    <div
      id={@id}
      phx-drop-target={@upload.ref}
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
        <.live_img_preview
          :for={entry <- @upload.entries}
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
