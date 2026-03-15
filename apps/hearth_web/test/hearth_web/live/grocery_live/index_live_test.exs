defmodule HearthWeb.GroceryLive.IndexTest do
  use HearthWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import HearthWeb.GroceryFixtures
  import HearthWeb.CalendarFixtures

  describe "Grocery page" do
    setup :register_and_log_in_user

    test "renders page header with Grocery and Add List", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/grocery")
      assert html =~ "Grocery"
      assert html =~ "Add List"
    end

    test "shows empty state with no lists", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/grocery")
      assert html =~ "No grocery lists yet"
    end

    test "shows existing lists", %{conn: conn, scope: scope} do
      list = grocery_list_fixture(scope, %{"name" => "Weekly Shopping"})

      {:ok, _view, html} = live(conn, ~p"/grocery")
      assert html =~ list.name
    end

    test "opens list form via Add List button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/grocery")

      view |> element("button", "Add List") |> render_click()
      assert render(view) =~ "New List"
    end

    test "creates list via form submit", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/grocery")

      view |> element("button", "Add List") |> render_click()

      view
      |> form("form", grocery_list: %{name: "Weekend Shopping"})
      |> render_submit()

      assert render(view) =~ "Weekend Shopping"
    end

    test "validates blank list name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/grocery")

      view |> element("button", "Add List") |> render_click()

      view
      |> form("form", grocery_list: %{name: ""})
      |> render_submit()

      assert render(view) =~ "can&#39;t be blank"
    end

    test "selects list and shows items section", %{conn: conn, scope: scope} do
      list = grocery_list_fixture(scope, %{"name" => "My List"})

      {:ok, view, _html} = live(conn, ~p"/grocery")

      view
      |> element("[phx-click='select_list'][phx-value-id='#{list.id}']")
      |> render_click()

      assert render(view) =~ "Add Item"
    end

    test "creates item via item form", %{conn: conn, scope: scope} do
      list = grocery_list_fixture(scope, %{"name" => "Shopping"})

      {:ok, view, _html} = live(conn, ~p"/grocery")

      view
      |> element("[phx-click='select_list'][phx-value-id='#{list.id}']")
      |> render_click()

      view |> element("button", "+ Add Item") |> render_click()
      assert render(view) =~ "New Item"

      view
      |> form("form", grocery_item: %{name: "Eggs"})
      |> render_submit()

      assert render(view) =~ "Eggs"
    end

    test "toggles item checked via click", %{conn: conn, scope: scope} do
      list = grocery_list_fixture(scope, %{"name" => "Shopping"})
      item = grocery_item_fixture(scope, list, %{"name" => "Bread"})

      {:ok, view, _html} = live(conn, ~p"/grocery")

      view
      |> element("[phx-click='select_list'][phx-value-id='#{list.id}']")
      |> render_click()

      assert render(view) =~ "Bread"

      view
      |> element("[phx-click='toggle_item'][phx-value-id='#{item.id}']")
      |> render_click()

      assert render(view) =~ "line-through"
    end

    test "deletes item", %{conn: conn, scope: scope} do
      list = grocery_list_fixture(scope, %{"name" => "Shopping"})
      item = grocery_item_fixture(scope, list, %{"name" => "Butter"})

      {:ok, view, _html} = live(conn, ~p"/grocery")

      view
      |> element("[phx-click='select_list'][phx-value-id='#{list.id}']")
      |> render_click()

      assert render(view) =~ "Butter"

      view
      |> element("[phx-click='delete_item'][phx-value-id='#{item.id}']")
      |> render_click()

      refute render(view) =~ "Butter"
    end
  end

  describe "links" do
    setup :register_and_log_in_user

    test "linked events section appears when list is selected", %{conn: conn, scope: scope} do
      list = grocery_list_fixture(scope, %{"name" => "Shopping"})

      {:ok, view, _html} = live(conn, ~p"/grocery")

      view
      |> element("[phx-click='select_list'][phx-value-id='#{list.id}']")
      |> render_click()

      assert render(view) =~ "Linked Events"
    end

    test "can link and unlink a calendar event", %{conn: conn, scope: scope} do
      list = grocery_list_fixture(scope, %{"name" => "Shopping"})
      event = event_fixture(scope, %{"title" => "Dinner Party"})

      {:ok, view, _html} = live(conn, ~p"/grocery")

      view
      |> element("[phx-click='select_list'][phx-value-id='#{list.id}']")
      |> render_click()

      assert render(view) =~ "Dinner Party"

      view
      |> form("form[phx-submit='toggle_event_link']", %{event_id: event.id})
      |> render_submit()

      assert render(view) =~ "Unlink"

      view
      |> element("[phx-click='toggle_event_link'][phx-value-event_id='#{event.id}']")
      |> render_click()

      refute render(view) =~ "Unlink"
    end
  end
end
