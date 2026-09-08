defmodule BrainCloudWeb.Router do
  use BrainCloudWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug BrainCloudWeb.BrowserAuth
    plug :put_root_layout, html: {BrainCloudWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authenticated_api do
    plug BrainCloudWeb.Plugs.ApiAuth
  end

  scope "/", BrainCloudWeb do
    pipe_through :browser

    get "/sign-in", SignInController, :new
    post "/sign-in", SignInController, :create
    get "/sign-in/confirm", SignInController, :confirm
    post "/sign-in/confirm", SignInController, :consume
    post "/organizations/select", OrganizationSessionController, :update
    delete "/session", BrowserSessionController, :delete

    get "/organization/invitations", BrowserInvitationController, :index
    post "/organization/invitations", BrowserInvitationController, :create
    post "/organization/invitations/:id/send", BrowserInvitationController, :send_invitation
    delete "/organization/invitations/:id", BrowserInvitationController, :revoke
    get "/invitations/accept", BrowserInvitationController, :landing
    post "/invitations/preview", BrowserInvitationController, :preview
    post "/invitations/accept", BrowserInvitationController, :accept

    live_session :browser, on_mount: [{BrainCloudWeb.BrowserAuth, :current_scope}] do
      live "/", HomeLive, :index
    end
  end

  scope "/", BrainCloudWeb do
    pipe_through :api

    get "/healthz", HealthController, :show
    get "/readyz", ReadinessController, :show
    get "/v1/system/info", SystemInfoController, :show
    post "/v1/invitations/accept", InvitationAcceptanceController, :create
  end

  scope "/v1", BrainCloudWeb do
    pipe_through [:api, :authenticated_api]

    post "/auth/tokens", TokenController, :create
    get "/auth/tokens", TokenController, :index
    delete "/auth/tokens/:id", TokenController, :delete
    post "/organization/memberships", MembershipController, :create
    get "/organization/memberships", MembershipController, :index
    patch "/organization/memberships/:id", MembershipController, :update
    delete "/organization/memberships/:id", MembershipController, :delete
    post "/organization/memberships/:id/reactivate", MembershipController, :reactivate
    post "/organization/memberships/:id/tokens", MembershipController, :create_token
    post "/organization/invitations", InvitationController, :create
    get "/organization/invitations", InvitationController, :index
    delete "/organization/invitations/:id", InvitationController, :delete
    post "/organization/teams", TeamController, :create
    get "/organization/teams", TeamController, :index
    patch "/organization/teams/:id", TeamController, :update
    delete "/organization/teams/:id", TeamController, :delete
    post "/organization/teams/:id/reactivate", TeamController, :reactivate
    get "/organization/teams/:team_id/members", TeamMembershipController, :index
    put "/organization/teams/:team_id/members/:membership_id", TeamMembershipController, :update

    delete "/organization/teams/:team_id/members/:membership_id",
           TeamMembershipController,
           :delete

    post "/organization/agents", AgentController, :create
    get "/organization/agents", AgentController, :index
    patch "/organization/agents/:id", AgentController, :update
    delete "/organization/agents/:id", AgentController, :delete
    post "/organization/agents/:id/reactivate", AgentController, :reactivate
    post "/organization/agents/:agent_id/tokens", AgentTokenController, :create
    get "/organization/agents/:agent_id/tokens", AgentTokenController, :index
    delete "/organization/agents/:agent_id/tokens/:id", AgentTokenController, :delete

    get "/projects", ProjectController, :index
    post "/projects", ProjectController, :create
    get "/projects/:id", ProjectController, :show
    get "/projects/:project_id/access", ProjectAccessController, :index
    put "/projects/:project_id/access/:membership_id", ProjectAccessController, :update
    delete "/projects/:project_id/access/:membership_id", ProjectAccessController, :delete
    get "/projects/:project_id/team-access", TeamProjectAccessController, :index
    put "/projects/:project_id/team-access/:team_id", TeamProjectAccessController, :update
    delete "/projects/:project_id/team-access/:team_id", TeamProjectAccessController, :delete
    get "/projects/:project_id/agent-access", AgentProjectAccessController, :index

    put "/projects/:project_id/agent-access/:agent_id",
        AgentProjectAccessController,
        :update

    delete "/projects/:project_id/agent-access/:agent_id",
           AgentProjectAccessController,
           :delete

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
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
