defmodule BrainCloudWeb.Router do
  use BrainCloudWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BrainCloudWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authenticated_api do
    plug BrainCloudWeb.Plugs.DevAuth
  end

  scope "/", BrainCloudWeb do
    pipe_through :browser

    live "/", HomeLive, :index
  end

  scope "/", BrainCloudWeb do
    pipe_through :api

    get "/healthz", HealthController, :show
    get "/readyz", ReadinessController, :show
    get "/v1/system/info", SystemInfoController, :show
  end

  scope "/v1", BrainCloudWeb do
    pipe_through [:api, :authenticated_api]

    post "/projects", ProjectController, :create
    post "/projects/:project_id/memories", MemoryController, :create
    get "/projects/:project_id/memories/:id", MemoryController, :show
    get "/projects/:project_id/search", SearchController, :index
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:brain_cloud_web, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BrainCloudWeb.Telemetry
    end
  end
end
