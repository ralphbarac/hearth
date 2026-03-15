defmodule HearthCalendar.EventExceptionTest do
  use HearthCalendar.DataCase, async: true

  alias HearthCalendar.EventException

  describe "changeset/2" do
    test "valid attrs produces valid changeset" do
      attrs = %{event_id: Ecto.UUID.generate(), excluded_date: ~D[2026-06-15]}
      changeset = EventException.changeset(%EventException{}, attrs)
      assert changeset.valid?
    end

    test "requires event_id" do
      changeset = EventException.changeset(%EventException{}, %{excluded_date: ~D[2026-06-15]})
      assert "can't be blank" in errors_on(changeset).event_id
    end

    test "requires excluded_date" do
      changeset = EventException.changeset(%EventException{}, %{event_id: Ecto.UUID.generate()})
      assert "can't be blank" in errors_on(changeset).excluded_date
    end
  end
end
