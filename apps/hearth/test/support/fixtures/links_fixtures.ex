defmodule Hearth.LinksFixtures do
  def link_fixture(scope, attrs \\ %{}) do
    {:ok, link} =
      Hearth.Links.create_link(
        scope,
        attrs[:source_type] || "calendar_event",
        attrs[:source_id] || Ecto.UUID.generate(),
        attrs[:target_type] || "grocery_list",
        attrs[:target_id] || Ecto.UUID.generate()
      )

    link
  end
end
