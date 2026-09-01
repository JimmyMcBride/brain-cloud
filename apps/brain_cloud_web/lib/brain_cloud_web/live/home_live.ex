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
      <section class="space-y-8">
        <div class="space-y-3">
          <p class="text-sm font-semibold uppercase tracking-[0.2em] text-cyan-700">
            Phase 2F API
          </p>
          <h1 class="text-4xl font-semibold tracking-tight text-slate-950 sm:text-5xl">
            Brain Cloud
          </h1>
          <p class="max-w-xl text-lg leading-8 text-slate-600">
            The hosted and self-hostable server for Brain Core and explicitly enabled modules.
            This bootstrap exposes production human and agent credentials, organization membership,
            direct, team, and agent project-access administration, and organization-scoped durable
            project memory with explicit human/agent provenance and bounded agent-authored writes;
            no product UI is implemented yet.
          </p>
        </div>

        <dl class="grid gap-4 sm:grid-cols-3">
          <div class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
            <dt class="text-sm text-slate-500">Protocol</dt>
            <dd class="mt-2 font-mono text-lg text-slate-950">{@system_info.protocol_version}</dd>
          </div>
          <div class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
            <dt class="text-sm text-slate-500">Server</dt>
            <dd class="mt-2 font-mono text-lg text-slate-950">
              {@system_info.server_version}
            </dd>
          </div>
          <div class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
            <dt class="text-sm text-slate-500">Enabled modules</dt>
            <dd class="mt-2 font-mono text-lg text-slate-950">
              {length(@system_info.modules)}
            </dd>
          </div>
        </dl>

        <nav aria-label="Server endpoints" class="flex flex-wrap gap-3">
          <a
            class="rounded-full bg-slate-950 px-5 py-3 text-sm font-medium text-white"
            href="/v1/system/info"
          >
            System information
          </a>
          <a
            class="rounded-full border border-slate-300 px-5 py-3 text-sm font-medium text-slate-800"
            href="/healthz"
          >
            Health
          </a>
          <a
            class="rounded-full border border-slate-300 px-5 py-3 text-sm font-medium text-slate-800"
            href="/readyz"
          >
            Readiness
          </a>
        </nav>
      </section>
    </Layouts.app>
    """
  end
end
