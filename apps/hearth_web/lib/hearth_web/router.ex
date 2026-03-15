defmodule HearthWeb.Router do
  use HearthWeb, :router

  import HearthWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HearthWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", HearthWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", HearthWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:hearth_web, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: HearthWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", HearthWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/setup", SetupController, :new
    post "/setup", SetupController, :create
    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
  end

  scope "/", HearthWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :authenticated,
      layout: {HearthWeb.Layouts, :app},
      on_mount: [{HearthWeb.UserAuth, :ensure_authenticated}] do
      live "/dashboard", HomeLive
      live "/calendar", CalendarLive.Index
      live "/budget", BudgetLive.Index
      live "/budget/goals", GoalsLive.Index
      live "/grocery", GroceryLive.Index
      live "/bills", BillsLive.Index
      live "/inventory", InventoryLive.Index
      live "/recipes", RecipesLive.Index, :index
      live "/recipes/:id", RecipesLive.Show, :show
      live "/meal-plan", MealPlanLive
      live "/contacts", ContactsLive.Index
      live "/documents", DocumentsLive.Index
      live "/chores", ChoresLive.Index
      live "/maintenance", MaintenanceLive.Index
    end

    live_session :admin,
      layout: {HearthWeb.Layouts, :app},
      on_mount: [{HearthWeb.UserAuth, :ensure_admin}] do
      live "/admin/users", Admin.UsersLive
      live "/admin/household", Admin.HouseholdLive
      live "/admin/features", Admin.FeaturesLive
      live "/admin/categories", Admin.CategoriesLive
    end

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
  end

  scope "/", HearthWeb do
    pipe_through [:browser]

    get "/users/log-in", UserSessionController, :new
    get "/users/log-in/:token", UserSessionController, :confirm
    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
