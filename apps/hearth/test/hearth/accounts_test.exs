defmodule Hearth.AccountsTest do
  use Hearth.DataCase

  alias Hearth.Accounts

  import Hearth.AccountsFixtures
  alias Hearth.Accounts.{User, UserToken}

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_email(user.email)
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the user if the password is not valid" do
      user = user_fixture()
      refute Accounts.get_user_by_email_and_password(user.email, "invalid")
    end

    test "returns the user if the email and password are valid" do
      %{id: id} = user = user_fixture()

      assert %User{id: ^id} =
               Accounts.get_user_by_email_and_password(user.email, valid_user_password())
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!("11111111-1111-1111-1111-111111111111")
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user!(user.id)
    end
  end

  describe "register_user/1" do
    test "requires email, username, and password to be set" do
      {:error, changeset} = Accounts.register_user(%{})

      assert %{
               email: ["can't be blank"],
               username: ["can't be blank"],
               password: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email when given" do
      {:error, changeset} =
        Accounts.register_user(%{
          email: "not valid",
          username: "test",
          password: valid_user_password()
        })

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum values for email for security" do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.register_user(%{
          email: too_long,
          username: "test",
          password: valid_user_password()
        })

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness" do
      %{email: email} = user_fixture()

      {:error, changeset} =
        Accounts.register_user(%{
          email: email,
          username: "other",
          password: valid_user_password()
        })

      assert "has already been taken" in errors_on(changeset).email

      {:error, changeset} =
        Accounts.register_user(%{
          email: String.upcase(email),
          username: "other2",
          password: valid_user_password()
        })

      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers users with password" do
      email = unique_user_email()
      username = unique_username()

      {:ok, user} =
        Accounts.register_user(%{
          email: email,
          username: username,
          password: valid_user_password()
        })

      assert user.email == email
      assert user.username == username
      assert is_binary(user.hashed_password)
      assert is_nil(user.confirmed_at)
      assert is_nil(user.password)
    end
  end

  describe "setup_first_household/2" do
    test "creates household and admin user" do
      assert {:ok, %{household: household, user: user}} =
               Accounts.setup_first_household(
                 %{name: "Test Household"},
                 %{
                   "email" => unique_user_email(),
                   "username" => unique_username(),
                   "password" => valid_user_password()
                 }
               )

      assert household.name == "Test Household"
      assert household.created_by_id == user.id
      assert user.role == "admin"
      assert user.household_id == household.id
    end
  end

  describe "admin_create_user/2" do
    test "creates a confirmed user in the admin's household" do
      admin = user_fixture(%{role: "admin"})
      scope = user_scope_fixture(admin)

      attrs = %{
        "email" => unique_user_email(),
        "username" => unique_username(),
        "password" => valid_user_password(),
        "password_confirmation" => valid_user_password(),
        "role" => "adult"
      }

      assert {:ok, user} = Accounts.admin_create_user(scope, attrs)
      assert user.household_id == scope.household.id
      assert user.confirmed_at != nil
    end

    test "returns error with invalid attrs" do
      admin = user_fixture(%{role: "admin"})
      scope = user_scope_fixture(admin)

      assert {:error, changeset} = Accounts.admin_create_user(scope, %{})
      assert errors_on(changeset)[:email]
      assert errors_on(changeset)[:password]
    end

    test "returns error when password confirmation does not match" do
      admin = user_fixture(%{role: "admin"})
      scope = user_scope_fixture(admin)

      attrs = %{
        "email" => unique_user_email(),
        "username" => unique_username(),
        "password" => valid_user_password(),
        "password_confirmation" => "wrong password"
      }

      assert {:error, changeset} = Accounts.admin_create_user(scope, attrs)
      assert errors_on(changeset)[:password_confirmation]
    end

    test "raises FunctionClauseError when caller is not admin" do
      user = user_fixture()
      scope = user_scope_fixture(user)

      assert_raise FunctionClauseError, fn ->
        Accounts.admin_create_user(scope, %{})
      end
    end
  end

  describe "feature_enabled?/2" do
    test "returns false when household feature is off regardless of user" do
      household =
        household_fixture(%{
          features: %{"calendar" => false, "budget" => true, "grocery" => true}
        })

      user = user_fixture(%{household: household})
      scope = user_scope_fixture(user)

      refute Accounts.feature_enabled?(scope, "calendar")
      assert Accounts.feature_enabled?(scope, "budget")
    end

    test "returns true when household feature is on and user has no override" do
      user = user_fixture()
      scope = user_scope_fixture(user)

      assert Accounts.feature_enabled?(scope, "calendar")
      assert Accounts.feature_enabled?(scope, "budget")
      assert Accounts.feature_enabled?(scope, "grocery")
    end

    test "returns false when household feature is on but user override is false" do
      user = user_fixture()
      household = user.household

      {:ok, restricted_user} =
        user
        |> User.features_changeset(%{"calendar" => false, "budget" => true, "grocery" => true})
        |> Hearth.Repo.update()

      scope = %Hearth.Accounts.Scope{user: restricted_user, household: household}

      refute Accounts.feature_enabled?(scope, "calendar")
      assert Accounts.feature_enabled?(scope, "budget")
    end
  end

  describe "sudo_mode?/2" do
    test "validates the authenticated_at time" do
      now = NaiveDateTime.utc_now()

      assert Accounts.sudo_mode?(%User{authenticated_at: NaiveDateTime.utc_now()})
      assert Accounts.sudo_mode?(%User{authenticated_at: NaiveDateTime.add(now, -19, :minute)})
      refute Accounts.sudo_mode?(%User{authenticated_at: NaiveDateTime.add(now, -21, :minute)})

      refute Accounts.sudo_mode?(
               %User{authenticated_at: NaiveDateTime.add(now, -11, :minute)},
               -10
             )

      refute Accounts.sudo_mode?(%User{})
    end
  end

  describe "change_user_email/3" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_email(%User{})
      assert changeset.required == [:email]
    end
  end

  describe "deliver_user_update_email_instructions/3" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(user, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "change:current@example.com"
    end
  end

  describe "update_user_email/2" do
    setup do
      user = user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{user: user, token: token, email: email}
    end

    test "updates the email with a valid token", %{user: user, token: token, email: email} do
      assert {:ok, %{email: ^email}} = Accounts.update_user_email(user, token)
      changed_user = Repo.get!(User, user.id)
      assert changed_user.email != user.email
      assert changed_user.email == email
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email with invalid token", %{user: user} do
      assert Accounts.update_user_email(user, "oops") ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if user email changed", %{user: user, token: token} do
      assert Accounts.update_user_email(%{user | email: "current@example.com"}, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])

      assert Accounts.update_user_email(user, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "change_user_password/3" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_password(%User{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_user_password(
          %User{},
          %{
            "password" => "new valid password"
          },
          hash_password: false
        )

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_user_password/2" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_user_password(user, %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{user: user} do
      {:ok, {user, expired_tokens}} =
        Accounts.update_user_password(user, %{
          password: "new valid password"
        })

      assert expired_tokens == []
      assert is_nil(user.password)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)

      {:ok, {_, _}} =
        Accounts.update_user_password(user, %{
          password: "new valid password"
        })

      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"
      assert user_token.authenticated_at != nil

      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "session"
        })
      end
    end

    test "duplicates the authenticated_at of given user in new token", %{user: user} do
      user = %{user | authenticated_at: NaiveDateTime.add(NaiveDateTime.utc_now(:second), -3600)}
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.authenticated_at == user.authenticated_at
      assert NaiveDateTime.compare(user_token.inserted_at, user.authenticated_at) == :gt
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert {session_user, token_inserted_at} = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
      assert session_user.authenticated_at != nil
      assert token_inserted_at != nil
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      dt = ~N[2020-01-01 00:00:00]
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: dt, authenticated_at: dt])
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "update_user_role/3" do
    test "updates the role of a household member" do
      admin = user_fixture(%{role: "admin"})
      scope = user_scope_fixture(admin)
      member = user_fixture(%{household: admin.household, role: "adult"})

      assert {:ok, updated} = Accounts.update_user_role(scope, member, "child")
      assert updated.role == "child"
    end

    test "raises FunctionClauseError when user is from a different household" do
      admin = user_fixture(%{role: "admin"})
      scope = user_scope_fixture(admin)
      other_user = user_fixture()

      assert_raise FunctionClauseError, fn ->
        Accounts.update_user_role(scope, other_user, "adult")
      end
    end

    test "raises FunctionClauseError for invalid role" do
      admin = user_fixture(%{role: "admin"})
      scope = user_scope_fixture(admin)
      member = user_fixture(%{household: admin.household})

      assert_raise FunctionClauseError, fn ->
        Accounts.update_user_role(scope, member, "superuser")
      end
    end
  end

  describe "delete_user/2" do
    test "deletes a household member" do
      admin = user_fixture(%{role: "admin"})
      scope = user_scope_fixture(admin)
      member = user_fixture(%{household: admin.household})

      assert {:ok, _} = Accounts.delete_user(scope, member)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(member.id) end
    end

    test "returns error when attempting to delete yourself" do
      admin = user_fixture(%{role: "admin"})
      scope = user_scope_fixture(admin)

      assert {:error, :cannot_delete_self} = Accounts.delete_user(scope, admin)
    end

    test "returns error when target user is from a different household" do
      admin = user_fixture(%{role: "admin"})
      scope = user_scope_fixture(admin)
      other_user = user_fixture()

      assert {:error, :not_found} = Accounts.delete_user(scope, other_user)
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
