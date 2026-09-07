defmodule BrainCloudWeb.HomeLive do
  use BrainCloudWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Brain Cloud")
     |> assign(:system_info, BrainCloud.SystemInfo.get())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section class="space-y-10">
        <header class="space-y-4 border-b border-slate-200 pb-8">
          <div class="flex flex-wrap items-center justify-between gap-4">
            <p class="text-sm font-semibold uppercase tracking-[0.2em] text-cyan-700">
              Phase 2H foundation
            </p>
            <.identity_action current_scope={@current_scope} />
          </div>
          <h1 class="text-4xl font-semibold tracking-tight text-slate-950 sm:text-5xl">
            Brain Cloud
          </h1>
          <p class="max-w-2xl text-lg leading-8 text-slate-600">
            The hosted and self-hostable server for Brain Core. Existing members can now sign in
            to an organization-aware browser shell; product workflows remain API-only.
          </p>
        </header>

        <.browser_state current_scope={@current_scope} />

        <dl class="grid gap-4 sm:grid-cols-3">
          <.fact label="Protocol" value={@system_info.protocol_version} />
          <.fact label="Server" value={@system_info.server_version} />
          <.fact label="Enabled modules" value={length(@system_info.modules)} />
        </dl>

        <nav aria-label="Server endpoints" class="flex flex-wrap gap-3">
          <.endpoint href={~p"/v1/system/info"}>System information</.endpoint>
          <.endpoint href={~p"/healthz"}>Health</.endpoint>
          <.endpoint href={~p"/readyz"}>Readiness</.endpoint>
        </nav>
      </section>
    </Layouts.app>
    """
  end

  attr :current_scope, :any, required: true

  defp identity_action(%{current_scope: nil} = assigns) do
    ~H"""
    <a
      href={~p"/sign-in"}
      class="rounded-full bg-slate-950 px-5 py-2.5 text-sm font-semibold text-white"
    >
      Sign in
    </a>
    """
  end

  defp identity_action(assigns) do
    ~H"""
    <form action={~p"/session"} method="post">
      <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
      <input type="hidden" name="_method" value="delete" />
      <button type="submit" class="text-sm font-semibold text-slate-700 hover:text-slate-950">
        Sign out
      </button>
    </form>
    """
  end

  attr :current_scope, :any, required: true

  defp browser_state(%{current_scope: nil} = assigns) do
    ~H"""
    <div id="signed-out" class="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
      <h2 class="text-xl font-semibold text-slate-950">Server foundation ready</h2>
      <p class="mt-2 max-w-2xl leading-7 text-slate-600">
        Sign-in is closed to existing users with an active organization membership. This is an
        identity shell, not a project or administration dashboard.
      </p>
    </div>
    """
  end

  defp browser_state(%{current_scope: %{selected_membership: nil}} = assigns) do
    ~H"""
    <div
      id="organization-chooser"
      class="space-y-5 rounded-2xl border border-slate-200 bg-white p-6 shadow-sm"
    >
      <div>
        <p class="text-sm text-slate-500">Signed in as {@current_scope.user.display_name}</p>
        <h2 class="mt-1 text-2xl font-semibold text-slate-950">Choose an organization</h2>
      </div>
      <div class="grid gap-3 sm:grid-cols-2">
        <.organization_button :for={membership <- @current_scope.memberships} membership={membership} />
      </div>
    </div>
    """
  end

  defp browser_state(assigns) do
    ~H"""
    <div id="signed-in" class="space-y-6 rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
      <div>
        <p class="text-sm text-slate-500">Signed in as {@current_scope.user.display_name}</p>
        <h2 class="mt-1 text-2xl font-semibold text-slate-950">
          {@current_scope.organization.name}
        </h2>
        <p class="mt-2 text-sm text-slate-600">Current role: {@current_scope.role}</p>
        <.link
          :if={@current_scope.role == "owner"}
          href={~p"/organization/invitations"}
          class="mt-4 inline-block text-cyan-700 underline"
        >Invite members</.link>
      </div>

      <div
        :if={length(@current_scope.memberships) > 1}
        class="space-y-3 border-t border-slate-100 pt-5"
      >
        <p class="text-sm font-medium text-slate-700">Switch organization</p>
        <div class="flex flex-wrap gap-3">
          <.organization_button
            :for={membership <- @current_scope.memberships}
            :if={membership.id != @current_scope.selected_membership.id}
            membership={membership}
          />
        </div>
      </div>

      <p class="border-t border-slate-100 pt-5 text-sm leading-6 text-slate-500">
        Project, memory, team, agent, invitation, token, and administration workflows are not in
        this browser shell yet.
      </p>
    </div>
    """
  end

  attr :membership, :any, required: true

  defp organization_button(assigns) do
    ~H"""
    <form action={~p"/organizations/select"} method="post">
      <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
      <input type="hidden" name="membership_id" value={@membership.id} />
      <button
        type="submit"
        class="w-full rounded-xl border border-slate-300 px-4 py-3 text-left hover:border-cyan-700 hover:bg-cyan-50"
      >
        <span class="block font-semibold text-slate-950">{@membership.organization.name}</span>
        <span class="mt-1 block text-sm text-slate-500">{@membership.role}</span>
      </button>
    </form>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true

  defp fact(assigns) do
    ~H"""
    <div class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
      <dt class="text-sm text-slate-500">{@label}</dt>
      <dd class="mt-2 font-mono text-lg text-slate-950">{@value}</dd>
    </div>
    """
  end

  attr :href, :string, required: true
  slot :inner_block, required: true

  defp endpoint(assigns) do
    ~H"""
    <a
      class="rounded-full border border-slate-300 px-5 py-3 text-sm font-medium text-slate-800"
      href={@href}
    >
      {render_slot(@inner_block)}
    </a>
    """
  end
end
