defmodule HearthRecipes.TagsTest do
  use HearthRecipes.DataCase, async: true

  import Hearth.AccountsFixtures
  import HearthRecipes.RecipesFixtures

  alias HearthRecipes.Tags
  alias HearthRecipes.Tag

  describe "list_tags/1" do
    test "returns all tags for the household ordered by name" do
      scope = user_scope_fixture()
      tag_fixture(scope, %{"name" => "Vegan"})
      tag_fixture(scope, %{"name" => "Quick"})

      tags = Tags.list_tags(scope)
      names = Enum.map(tags, & &1.name)
      assert names == Enum.sort(names)
      assert "Vegan" in names
      assert "Quick" in names
    end

    test "returns empty list when no tags" do
      scope = user_scope_fixture()
      assert Tags.list_tags(scope) == []
    end

    test "isolates tags by household" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()
      tag_fixture(scope1, %{"name" => "Scope1Tag"})
      tag_fixture(scope2, %{"name" => "Scope2Tag"})

      tags1 = Tags.list_tags(scope1)
      assert length(tags1) == 1
      assert hd(tags1).name == "Scope1Tag"
    end
  end

  describe "create_tag/2" do
    test "creates tag with valid attrs" do
      scope = user_scope_fixture()
      assert {:ok, %Tag{} = tag} = Tags.create_tag(scope, %{"name" => "Italian"})
      assert tag.name == "Italian"
      assert tag.household_id == scope.household.id
    end

    test "returns error when name is missing" do
      scope = user_scope_fixture()
      assert {:error, changeset} = Tags.create_tag(scope, %{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error when name exceeds 50 characters" do
      scope = user_scope_fixture()
      long_name = String.duplicate("a", 51)
      assert {:error, changeset} = Tags.create_tag(scope, %{"name" => long_name})
      assert %{name: [_]} = errors_on(changeset)
    end

    test "enforces uniqueness per household" do
      scope = user_scope_fixture()
      Tags.create_tag(scope, %{"name" => "Vegan"})
      assert {:error, changeset} = Tags.create_tag(scope, %{"name" => "Vegan"})
      assert %{household_id: [_]} = errors_on(changeset)
    end

    test "allows same name in different households" do
      scope1 = user_scope_fixture()
      scope2 = user_scope_fixture()
      assert {:ok, _} = Tags.create_tag(scope1, %{"name" => "Vegan"})
      assert {:ok, _} = Tags.create_tag(scope2, %{"name" => "Vegan"})
    end
  end

  describe "delete_tag/2" do
    test "removes tag" do
      scope = user_scope_fixture()
      tag = tag_fixture(scope)
      assert {:ok, _} = Tags.delete_tag(scope, tag)
      assert Tags.list_tags(scope) == []
    end
  end

  describe "find_or_create_tag/2" do
    test "creates tag if not found" do
      scope = user_scope_fixture()
      assert {:ok, %Tag{} = tag} = Tags.find_or_create_tag(scope, "NewTag")
      assert tag.name == "NewTag"
    end

    test "returns existing tag if found" do
      scope = user_scope_fixture()
      {:ok, existing} = Tags.create_tag(scope, %{"name" => "Existing"})
      {:ok, found} = Tags.find_or_create_tag(scope, "Existing")
      assert found.id == existing.id
    end
  end
end
