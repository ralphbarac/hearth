defmodule Hearth.LinksTest do
  use Hearth.DataCase, async: true

  import Hearth.AccountsFixtures
  import Hearth.LinksFixtures

  alias Hearth.Links
  alias Hearth.Links.Link

  describe "create_link/6" do
    test "creates link successfully" do
      scope = user_scope_fixture()
      source_id = Ecto.UUID.generate()
      target_id = Ecto.UUID.generate()

      assert {:ok, %Link{} = link} =
               Links.create_link(scope, "calendar_event", source_id, "grocery_list", target_id)

      assert link.source_type == "calendar_event"
      assert link.source_id == source_id
      assert link.target_type == "grocery_list"
      assert link.target_id == target_id
      assert link.household_id == scope.household.id
      assert link.created_by_id == scope.user.id
    end

    test "enforces household isolation" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()
      source_id = Ecto.UUID.generate()
      target_id = Ecto.UUID.generate()

      {:ok, _} = Links.create_link(scope1, "calendar_event", source_id, "grocery_list", target_id)

      assert Links.list_links_for(scope2, "calendar_event", source_id) == []
    end
  end

  describe "list_links_for/3" do
    test "returns links where source matches" do
      scope = user_scope_fixture()
      event_id = Ecto.UUID.generate()
      list_id = Ecto.UUID.generate()

      {:ok, link} = Links.create_link(scope, "calendar_event", event_id, "grocery_list", list_id)

      assert [^link] = Links.list_links_for(scope, "calendar_event", event_id)
    end

    test "returns links where target matches" do
      scope = user_scope_fixture()
      event_id = Ecto.UUID.generate()
      list_id = Ecto.UUID.generate()

      {:ok, link} = Links.create_link(scope, "calendar_event", event_id, "grocery_list", list_id)

      assert [^link] = Links.list_links_for(scope, "grocery_list", list_id)
    end

    test "excludes other households' links" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()
      shared_id = Ecto.UUID.generate()

      {:ok, _} =
        Links.create_link(
          scope1,
          "calendar_event",
          shared_id,
          "grocery_list",
          Ecto.UUID.generate()
        )

      assert Links.list_links_for(scope2, "calendar_event", shared_id) == []
    end
  end

  describe "get_linked_ids/4" do
    test "returns correct IDs from source side" do
      scope = user_scope_fixture()
      event_id = Ecto.UUID.generate()
      list_id = Ecto.UUID.generate()

      {:ok, _} = Links.create_link(scope, "calendar_event", event_id, "grocery_list", list_id)

      assert [^list_id] = Links.get_linked_ids(scope, "calendar_event", event_id, "grocery_list")
    end

    test "returns correct IDs from target side (reverse lookup)" do
      scope = user_scope_fixture()
      event_id = Ecto.UUID.generate()
      list_id = Ecto.UUID.generate()

      {:ok, _} = Links.create_link(scope, "calendar_event", event_id, "grocery_list", list_id)

      assert [^event_id] =
               Links.get_linked_ids(scope, "grocery_list", list_id, "calendar_event")
    end
  end

  describe "toggle_link/5" do
    test "creates link on first call" do
      scope = user_scope_fixture()
      event_id = Ecto.UUID.generate()
      list_id = Ecto.UUID.generate()

      assert {:ok, %Link{}} =
               Links.toggle_link(scope, "calendar_event", event_id, "grocery_list", list_id)

      assert [_] = Links.list_links_for(scope, "calendar_event", event_id)
    end

    test "deletes link on second call" do
      scope = user_scope_fixture()
      event_id = Ecto.UUID.generate()
      list_id = Ecto.UUID.generate()

      Links.toggle_link(scope, "calendar_event", event_id, "grocery_list", list_id)

      assert {:ok, %Link{}} =
               Links.toggle_link(scope, "calendar_event", event_id, "grocery_list", list_id)

      assert [] = Links.list_links_for(scope, "calendar_event", event_id)
    end
  end

  describe "delete_link/2" do
    test "removes link" do
      scope = user_scope_fixture()
      link = link_fixture(scope)

      assert {:ok, _} = Links.delete_link(scope, link)

      assert Links.get_link(
               scope,
               link.source_type,
               link.source_id,
               link.target_type,
               link.target_id
             ) == nil
    end

    test "cannot delete another household's link" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()
      link = link_fixture(scope1)

      assert {:error, :unauthorized} = Links.delete_link(scope2, link)
    end
  end
end
