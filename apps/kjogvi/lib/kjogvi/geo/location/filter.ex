defmodule Kjogvi.Geo.Location.Filter do
  @moduledoc """
  Purpose-driven refinement of a location query.

  Unlike the visibility scope (whose locations a user may see at all), the filter
  captures *what subset is relevant* for a given affordance — e.g. the checklist form's
  location picker excludes `special` locations, which a checklist may never reference
  directly.

  Built either as a bare `%Filter{}` (blank, no-op) or via a named constructor
  such as `for_checklist_input/0`. Applied to a query by `Location.Query.apply_filter/2`.
  """

  @schema [
    exclude_specials: [
      type: :boolean,
      default: false
    ],
    exclude_sections: [
      type: :boolean,
      default: false
    ],
    only_common: [
      type: :boolean,
      default: false
    ],
    exclude_disabled: [
      type: :boolean,
      default: false
    ],
    # A %Location{} or nil. Typed :any — naming the module here would be a
    # compile-time reference back into the Location cycle (xref).
    within: [
      type: :any,
      default: nil
    ]
  ]

  use Kjogvi.Filter, schema: @schema

  @type t() :: %__MODULE__{}

  @doc """
  Filter for the checklist add/edit location picker: hides `special` locations, since a
  checklist's location must be a concrete hierarchy location, and `disabled` locations,
  which are no longer offered for selection (an already-chosen disabled location still
  saves).
  """
  def for_checklist_input do
    %__MODULE__{exclude_specials: true, exclude_disabled: true}
  end

  @doc """
  Filter for the location parent picker: hides locations that can't be a parent —
  `special` (outside the hierarchy) and `section` (the lowest level, never an
  ancestor) — and `disabled` locations, no longer offered as a parent (an
  already-chosen disabled parent still saves).
  """
  def for_parent_pick do
    %__MODULE__{exclude_specials: true, exclude_sections: true, exclude_disabled: true}
  end

  @doc """
  Filter for the admin common-location parent picker: `for_parent_pick/0`
  restricted to common locations — a common location may not hang under
  anyone's personal location.
  """
  def for_common_parent_pick do
    %__MODULE__{
      only_common: true,
      exclude_specials: true,
      exclude_sections: true,
      exclude_disabled: true
    }
  end

  @doc """
  Filter for the special-location member picker: hides `special` locations, since
  a special may not be a member of another special. When the special sits under a
  `parent`, restricts to that parent's descendants — every member must belong to
  it (see `Location.special_members_changeset/2`); a parentless special accepts
  members anywhere.
  """
  def for_special_members(parent \\ nil) do
    %__MODULE__{exclude_specials: true, within: parent}
  end

  @doc """
  Filter for the eBird workbench link picker: common locations only, specials
  excluded, and `disabled` locations too — retired entries the matching passes
  never claim either, so the picker offers nothing a pass wouldn't. When the
  eBird country row is already linked, pass its common `country` to restrict
  candidates to that country's descendants.
  """
  def for_ebird_link(country \\ nil) do
    %__MODULE__{
      only_common: true,
      exclude_specials: true,
      exclude_disabled: true,
      within: country
    }
  end
end
