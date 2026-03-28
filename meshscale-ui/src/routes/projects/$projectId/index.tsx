import { createFileRoute, Link, notFound } from "@tanstack/react-router"
import { useState } from "react"
import {
  AlertCircle,
  Boxes,
  Globe,
  Gamepad2,
  Code2,
  Cpu,
  Clock,
  ArrowLeft,
  LayoutDashboard,
  Rocket,
  ScrollText,
  KeyRound,
  Settings,
  ExternalLink,
  MapPin,
  CheckCircle2,
  XCircle,
  Loader2,
  GitCommit,
  GitBranch,
  User,
  RefreshCw,
  Activity,
  Zap,
  MemoryStick,
  Server,
} from "lucide-react"
import { SidebarInset, SidebarProvider } from "@/components/ui/sidebar"
import { AppSidebar } from "@/routes/dashboard/components/sidebar/app-sidebar"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { Separator } from "@/components/ui/separator"
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert"
import { RelativeTime } from "@/components/relative-time"
import { useControlPlaneData } from "@/hooks/use-control-plane-data"
import type { ControlPlaneRuntimeOutput } from "@/lib/api"
import type {
  Project,
  ProjectApp,
  Deployment,
  ProjectType,
  ProjectStatus,
  DeploymentStatus,
} from "../data"

export const Route = createFileRoute("/projects/$projectId/")({
  component: ProjectDetail,
})

type NavSection =
  | "overview"
  | "apps"
  | "deployments"
  | "logs"
  | "environment"
  | "settings"

const typeConfig: Record<
  ProjectType,
  { icon: React.ElementType; label: string; color: string }
> = {
  project: {
    icon: Boxes,
    label: "Project",
    color: "text-sky-600 bg-sky-500/10",
  },
  website: {
    icon: Globe,
    label: "Website",
    color: "text-blue-500 bg-blue-500/10",
  },
  "game-server": {
    icon: Gamepad2,
    label: "Game Server",
    color: "text-purple-500 bg-purple-500/10",
  },
  api: { icon: Code2, label: "API", color: "text-green-500 bg-green-500/10" },
  worker: {
    icon: Cpu,
    label: "Worker",
    color: "text-orange-500 bg-orange-500/10",
  },
  cron: {
    icon: Clock,
    label: "Cron Job",
    color: "text-yellow-500 bg-yellow-500/10",
  },
}

const statusConfig: Record<
  ProjectStatus,
  { label: string; dot: string; badge: string }
> = {
  running: {
    label: "Running",
    dot: "bg-green-500",
    badge: "text-green-600 dark:text-green-400 bg-green-500/10",
  },
  stopped: {
    label: "Stopped",
    dot: "bg-gray-400",
    badge: "text-gray-500 dark:text-gray-400 bg-gray-500/10",
  },
  deploying: {
    label: "Deploying",
    dot: "bg-yellow-500 animate-pulse",
    badge: "text-yellow-600 dark:text-yellow-400 bg-yellow-500/10",
  },
  error: {
    label: "Error",
    dot: "bg-red-500",
    badge: "text-red-600 dark:text-red-400 bg-red-500/10",
  },
}

const deploymentStatusConfig: Record<
  DeploymentStatus,
  { icon: React.ElementType; label: string; color: string }
> = {
  success: {
    icon: CheckCircle2,
    label: "Success",
    color: "text-green-500",
  },
  failed: { icon: XCircle, label: "Failed", color: "text-red-500" },
  "in-progress": {
    icon: Loader2,
    label: "In Progress",
    color: "text-yellow-500",
  },
}

const navItems: { id: NavSection; label: string; icon: React.ElementType }[] =
  [
    { id: "overview", label: "Overview", icon: LayoutDashboard },
    { id: "apps", label: "Apps", icon: Server },
    { id: "deployments", label: "Deployments", icon: Rocket },
    { id: "logs", label: "Logs", icon: ScrollText },
    { id: "environment", label: "Environment", icon: KeyRound },
    { id: "settings", label: "Settings", icon: Settings },
  ]

function ProjectDetail() {
  const { projectId } = Route.useParams()
  const [activeSection, setActiveSection] = useState<NavSection>("overview")

  const {
    snapshot,
    projects,
    deployments: allDeployments,
    isLoading,
    error,
    refetch,
  } = useControlPlaneData()
  const project = projects.find((candidate) => candidate.id === projectId)
  const deployments = allDeployments.filter(
    (deployment) => deployment.projectId === projectId,
  )
  const runtimeOutputs = snapshot?.runtimeOutputs ?? []
  const apps = project?.apps ?? []
  const appCount = project?.appCount ?? apps.length

  // Still loading
  if (isLoading && !project) {
    return (
      <div className="flex h-screen items-center justify-center">
        <Loader2 className="size-5 animate-spin text-muted-foreground" />
      </div>
    )
  }

  if (error && !project) {
    return (
      <div className="flex h-screen items-center justify-center p-6">
        <div className="w-full max-w-lg">
          <Alert variant="destructive">
            <AlertCircle className="size-4" />
            <AlertTitle>Control plane unavailable</AlertTitle>
            <AlertDescription>
              <div className="flex flex-col gap-2">
                <p>{error}</p>
                <Button
                  variant="outline"
                  size="sm"
                  className="w-fit"
                  onClick={() => void refetch()}
                >
                  Retry
                </Button>
              </div>
            </AlertDescription>
          </Alert>
        </div>
      </div>
    )
  }

  // Not found
  if (!project) {
    throw notFound()
  }

  const type = typeConfig[project.type]
  const status = statusConfig[project.status]
  const TypeIcon = type.icon

  return (
    <SidebarProvider
      className="flex h-screen"
      style={
        {
          "--sidebar-width": "calc(var(--spacing) * 64)",
          "--header-height": "calc(var(--spacing) * 12 + 1px)",
        } as React.CSSProperties
      }
    >
      <AppSidebar variant="sidebar" />
      <SidebarInset className="flex flex-col overflow-hidden">
        {/* Top header */}
        <header className="bg-background/90 sticky top-0 z-10 flex h-(--header-height) shrink-0 items-center gap-2 border-b transition-[width,height] ease-linear">
          <div className="flex w-full items-center gap-2 px-4 lg:gap-3 lg:px-6">
            <Link
              to="/projects"
              className="flex items-center gap-1.5 text-sm text-muted-foreground transition-colors hover:text-foreground"
            >
              <ArrowLeft className="size-4" />
              Projects
            </Link>
            <span className="text-muted-foreground">/</span>
            <div className="flex items-center gap-2">
              <div
                className={`flex size-6 items-center justify-center rounded ${type.color}`}
              >
                <TypeIcon className="size-3.5" />
              </div>
              <span className="text-sm font-medium">{project.name}</span>
              <Badge
                variant="secondary"
                className={`flex items-center gap-1.5 px-2 py-0.5 text-xs font-medium ${status.badge}`}
              >
                <span className={`size-1.5 rounded-full ${status.dot}`} />
                {status.label}
              </Badge>
            </div>
            <div className="ml-auto flex items-center gap-2">
              {project.url && (
                <a
                  href={project.url}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <Button variant="outline" size="sm" className="gap-1.5">
                    <ExternalLink className="size-3.5" />
                    Visit
                  </Button>
                </a>
              )}
              <Button size="sm" className="gap-1.5">
                <Rocket className="size-3.5" />
                Deploy
              </Button>
            </div>
          </div>
        </header>

        {/* Body: project sidebar + main content */}
        <div className="flex flex-1 overflow-hidden">
          {/* Project sidebar */}
          <aside className="flex w-64 shrink-0 flex-col border-r bg-muted/30">
            <div className="flex flex-col gap-1 p-3">
              {navItems.map((item) => {
                const Icon = item.icon
                return (
                  <button
                    key={item.id}
                    onClick={() => setActiveSection(item.id)}
                    className={`flex items-center gap-2.5 rounded-md px-3 py-2 text-sm font-medium transition-colors ${
                      activeSection === item.id
                        ? "bg-background text-foreground ring-1 ring-border"
                        : "text-muted-foreground hover:bg-background/60 hover:text-foreground"
                    }`}
                  >
                    <Icon className="size-4 shrink-0" />
                    {item.label}
                  </button>
                )
              })}
            </div>

            <Separator />

            {/* Project meta */}
            <div className="flex flex-col gap-3 p-4 text-xs text-muted-foreground">
              <div className="flex flex-col gap-1">
                <span className="font-medium text-foreground">Region</span>
                <div className="flex items-center gap-1.5">
                  <MapPin className="size-3" />
                  {project.region}
                </div>
              </div>
              <div className="flex flex-col gap-1">
                <span className="font-medium text-foreground">Apps</span>
                <div className="flex items-center gap-1.5">
                  <Server className="size-3" />
                  {appCount} deployed
                </div>
              </div>
              <div className="flex flex-col gap-1">
                <span className="font-medium text-foreground">Containers</span>
                <div className="flex items-center gap-1.5">
                  <Boxes className="size-3" />
                  {project.instances}/{project.desiredInstances ?? project.instances} running
                </div>
              </div>
              <div className="flex flex-col gap-1">
                <span className="font-medium text-foreground">Type</span>
                <div className="flex items-center gap-1.5">
                  <TypeIcon className="size-3" />
                  {type.label}
                </div>
              </div>
              {project.url && (
                <div className="flex flex-col gap-1">
                  <span className="font-medium text-foreground">URL</span>
                  <a
                    href={project.url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="truncate text-blue-500 hover:underline"
                  >
                    {project.url.replace("https://", "")}
                  </a>
                </div>
              )}
              {project.image && (
                <div className="flex flex-col gap-1">
                  <span className="font-medium text-foreground">Image</span>
                  <span className="truncate">{project.image}</span>
                </div>
              )}
            </div>
          </aside>

          {/* Main content */}
          <main className="flex-1 overflow-y-auto">
            {error && (
              <div className="p-6 pb-0">
                <Alert variant="destructive">
                  <AlertCircle className="size-4" />
                  <AlertTitle>Showing the last known project state</AlertTitle>
                  <AlertDescription>
                    <div className="flex flex-col gap-2">
                      <p>{error}</p>
                      <Button
                        variant="outline"
                        size="sm"
                        className="w-fit"
                        onClick={() => void refetch()}
                      >
                        Retry
                      </Button>
                    </div>
                  </AlertDescription>
                </Alert>
              </div>
            )}
            {activeSection === "overview" && (
              <OverviewSection
                project={project}
                apps={apps}
                deployments={deployments}
                runtimeOutputs={runtimeOutputs}
              />
            )}
            {activeSection === "apps" && <AppsSection apps={apps} />}
            {activeSection === "deployments" && (
              <DeploymentsSection
                project={project}
                deployments={deployments}
              />
            )}
            {activeSection === "logs" && (
              <PlaceholderSection
                title="Logs"
                description="Real-time and historical log streaming coming soon."
              />
            )}
            {activeSection === "environment" && (
              <PlaceholderSection
                title="Environment Variables"
                description="Manage environment variables and secrets for this project."
              />
            )}
            {activeSection === "settings" && (
              <PlaceholderSection
                title="Settings"
                description="Configure project name, region, scaling, and more."
              />
            )}
          </main>
        </div>
      </SidebarInset>
    </SidebarProvider>
  )
}

function OverviewSection({
  project,
  apps,
  deployments,
  runtimeOutputs,
}: {
  project: Project
  apps: ProjectApp[]
  deployments: Deployment[]
  runtimeOutputs: ControlPlaneRuntimeOutput[]
}) {
  const status = statusConfig[project.status]
  const appCount = project.appCount ?? apps.length

  return (
    <div className="flex flex-col gap-6 p-6">
      {/* Stat cards */}
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <Card>
          <CardHeader className="pb-2">
            <CardDescription className="flex items-center gap-1.5">
              <Activity className="size-3.5" />
              Status
            </CardDescription>
            <CardTitle className="text-base">
              <Badge
                variant="secondary"
                className={`flex w-fit items-center gap-1.5 ${status.badge}`}
              >
                <span className={`size-1.5 rounded-full ${status.dot}`} />
                {status.label}
              </Badge>
            </CardTitle>
          </CardHeader>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardDescription className="flex items-center gap-1.5">
              <Zap className="size-3.5" />
              Uptime
            </CardDescription>
            <CardTitle className="text-xl tabular-nums">
              {project.uptime}
            </CardTitle>
          </CardHeader>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardDescription className="flex items-center gap-1.5">
              <Cpu className="size-3.5" />
              Reserved CPU
            </CardDescription>
            <CardTitle className="text-xl tabular-nums">
              {project.cpu} CPU
            </CardTitle>
          </CardHeader>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardDescription className="flex items-center gap-1.5">
              <MemoryStick className="size-3.5" />
              Reserved Memory
            </CardDescription>
            <CardTitle className="text-xl tabular-nums">
              {project.memory} GB
            </CardTitle>
          </CardHeader>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-sm font-medium">Runtime Details</CardTitle>
          <CardDescription>
            Project-level state for the deployed Swift app
          </CardDescription>
        </CardHeader>
        <CardContent className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
          <InfoStat
            label="Apps"
            value={`${appCount}`}
          />
          <InfoStat
            label="Containers"
            value={`${project.instances}/${project.desiredInstances ?? project.instances}`}
          />
          <InfoStat
            label="Domain"
            value={project.url?.replace(/^https?:\/\//, "") ?? "not set"}
          />
          <InfoStat
            label="Reserved"
            value={`${project.cpu} CPU / ${project.memory} GB`}
          />
        </CardContent>
      </Card>

      {apps.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle className="text-sm font-medium">Apps</CardTitle>
            <CardDescription>
              Resources declared by your Swift app and the containers behind them
            </CardDescription>
          </CardHeader>
          <CardContent className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            {apps.map((app) => {
              const appStatus = statusConfig[app.status]
              return (
                <div
                  key={app.id}
                  className="rounded-lg border bg-muted/20 p-4"
                >
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <div className="font-medium">{app.name}</div>
                      <div className="mt-1 text-xs text-muted-foreground">
                        {app.description}
                      </div>
                    </div>
                    <Badge
                      variant="secondary"
                      className={`flex items-center gap-1.5 ${appStatus.badge}`}
                    >
                      <span className={`size-1.5 rounded-full ${appStatus.dot}`} />
                      {appStatus.label}
                    </Badge>
                  </div>
                  <div className="mt-4 grid grid-cols-2 gap-2 text-xs">
                    <div className="rounded-md border bg-background/70 p-2">
                      <div className="text-muted-foreground">Containers</div>
                      <div className="mt-1 font-medium">
                        {app.instances}/{app.desiredInstances}
                      </div>
                    </div>
                    <div className="rounded-md border bg-background/70 p-2">
                      <div className="text-muted-foreground">Ports</div>
                      <div className="mt-1 font-medium">
                        {app.ports?.length ? app.ports.join(", ") : "none"}
                      </div>
                    </div>
                  </div>
                </div>
              )
            })}
          </CardContent>
        </Card>
      )}

      {runtimeOutputs.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle className="text-sm font-medium">Swift Runtime Outputs</CardTitle>
            <CardDescription>
              Values published by your deployed Swift app during each tick
            </CardDescription>
          </CardHeader>
          <CardContent className="grid gap-4 md:grid-cols-2">
            {runtimeOutputs.map((output) => (
              <div
                key={output.key}
                className="rounded-lg border bg-muted/20 p-4"
              >
                <div className="text-xs font-medium uppercase tracking-[0.12em] text-muted-foreground">
                  {output.key}
                </div>
                <div className="mt-2 break-all font-mono text-sm text-foreground">
                  {output.value}
                </div>
                <div className="mt-2 text-xs text-muted-foreground">
                  Updated {new Date(output.updatedAt).toLocaleTimeString()}
                </div>
              </div>
            ))}
          </CardContent>
        </Card>
      )}

      {project.lastError && (
        <Alert variant="destructive">
          <AlertCircle className="size-4" />
          <AlertTitle>Latest worker error</AlertTitle>
          <AlertDescription>{project.lastError}</AlertDescription>
        </Alert>
      )}

      {/* Recent deployments */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <div>
            <CardTitle className="text-sm font-medium">
              Recent Deployments
            </CardTitle>
            <CardDescription>Latest deployment activity</CardDescription>
          </div>
          <Button variant="ghost" size="sm" className="gap-1.5 text-xs">
            <RefreshCw className="size-3" />
            Refresh
          </Button>
        </CardHeader>
        <CardContent className="flex flex-col gap-0 p-0">
          {deployments.length === 0 && (
            <p className="px-6 py-4 text-sm text-muted-foreground">
              No deployments yet.
            </p>
          )}
          {deployments.slice(0, 4).map((deployment, index) => {
            const ds = deploymentStatusConfig[deployment.status]
            const DIcon = ds.icon
            return (
              <div
                key={deployment.id}
                className={`flex items-center gap-4 px-6 py-4 ${
                  index !== Math.min(deployments.length, 4) - 1
                    ? "border-b"
                    : ""
                }`}
              >
                <DIcon
                  className={`size-4 shrink-0 ${ds.color} ${deployment.status === "in-progress" ? "animate-spin" : ""}`}
                />
                <div className="flex min-w-0 flex-1 flex-col gap-0.5">
                  <p className="truncate text-sm font-medium">
                    {deployment.message}
                  </p>
                  <div className="flex items-center gap-3 text-xs text-muted-foreground">
                    <span className="flex items-center gap-1">
                      <GitCommit className="size-3" />
                      {deployment.commit}
                    </span>
                    <span className="flex items-center gap-1">
                      <GitBranch className="size-3" />
                      {deployment.branch}
                    </span>
                    <span className="flex items-center gap-1">
                      <User className="size-3" />
                      {deployment.deployedBy}
                    </span>
                  </div>
                </div>
                <div className="flex flex-col items-end gap-0.5 text-xs text-muted-foreground">
                  <RelativeTime value={deployment.createdAt} fallback="never" />
                  <span>{deployment.duration}</span>
                </div>
              </div>
            )
          })}
        </CardContent>
      </Card>
    </div>
  )
}

function AppsSection({ apps }: { apps: ProjectApp[] }) {
  return (
    <div className="flex flex-col gap-6 p-6">
      <div>
        <h2 className="text-lg font-semibold">Apps</h2>
        <p className="text-sm text-muted-foreground">
          All apps declared by the deployed Swift source, plus their actual containers
        </p>
      </div>

      {apps.length === 0 && (
        <Card>
          <CardContent className="px-6 py-8 text-sm text-muted-foreground">
            No apps have been declared yet.
          </CardContent>
        </Card>
      )}

      {apps.map((app) => {
        const type = typeConfig[app.type]
        const status = statusConfig[app.status]
        const TypeIcon = type.icon

        return (
          <Card key={app.id}>
            <CardHeader>
              <div className="flex items-start justify-between gap-4">
                <div className="flex min-w-0 items-start gap-3">
                  <div
                    className={`mt-0.5 flex size-9 shrink-0 items-center justify-center rounded-lg ${type.color}`}
                  >
                    <TypeIcon className="size-4" />
                  </div>
                  <div className="min-w-0">
                    <CardTitle className="truncate text-base">{app.name}</CardTitle>
                    <CardDescription className="mt-1">
                      {app.description}
                    </CardDescription>
                  </div>
                </div>
                <div className="flex flex-wrap items-center justify-end gap-2">
                  <Badge
                    variant="secondary"
                    className={`flex items-center gap-1.5 ${status.badge}`}
                  >
                    <span className={`size-1.5 rounded-full ${status.dot}`} />
                    {status.label}
                  </Badge>
                  <Badge variant="outline">{type.label}</Badge>
                </div>
              </div>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid gap-4 md:grid-cols-4">
                <InfoStat
                  label="Containers"
                  value={`${app.instances}/${app.desiredInstances}`}
                />
                <InfoStat
                  label="Region"
                  value={app.region}
                />
                <InfoStat
                  label="Ports"
                  value={app.ports?.length ? app.ports.join(", ") : "none"}
                />
                <InfoStat
                  label="Image"
                  value={app.image ?? "unspecified"}
                />
              </div>

              {app.lastError && (
                <Alert variant="destructive">
                  <AlertCircle className="size-4" />
                  <AlertTitle>Latest app error</AlertTitle>
                  <AlertDescription>{app.lastError}</AlertDescription>
                </Alert>
              )}

              <div className="rounded-lg border">
                <div className="border-b px-4 py-3 text-sm font-medium">
                  Containers
                </div>
                <div className="flex flex-col">
                  {app.containers.map((container, index) => (
                    <div
                      key={container.id}
                      className={`flex flex-col gap-3 px-4 py-3 md:flex-row md:items-center ${
                        index !== app.containers.length - 1 ? "border-b" : ""
                      }`}
                    >
                      <div className="min-w-0 flex-1">
                        <div className="font-mono text-sm">{container.id}</div>
                        <div className="mt-1 text-xs text-muted-foreground">
                          {container.workerRegion
                            ? `${container.workerRegion}${container.workerId ? ` • ${container.workerId}` : ""}`
                            : container.workerId ?? "unassigned"}
                        </div>
                      </div>
                      <div className="flex flex-wrap items-center gap-2 text-xs">
                        <Badge
                          variant="outline"
                          className={containerStatusClassName(container.status)}
                        >
                          {container.status}
                        </Badge>
                        {container.image && (
                          <Badge variant="outline">{container.image}</Badge>
                        )}
                        {container.lastError && (
                          <span className="text-red-600 dark:text-red-400">
                            {container.lastError}
                          </span>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </CardContent>
          </Card>
        )
      })}
    </div>
  )
}

function DeploymentsSection({
  project,
  deployments,
}: {
  project: Project
  deployments: Deployment[]
}) {
  return (
    <div className="flex flex-col gap-6 p-6">
      <div>
        <h2 className="text-lg font-semibold">Deployments</h2>
        <p className="text-sm text-muted-foreground">
          Full deployment history for {project.name}
        </p>
      </div>
      <Card>
        <CardContent className="flex flex-col gap-0 p-0">
          {deployments.length === 0 && (
            <p className="px-6 py-4 text-sm text-muted-foreground">
              No deployments yet.
            </p>
          )}
          {deployments.map((deployment, index) => {
            const ds = deploymentStatusConfig[deployment.status]
            const DIcon = ds.icon
            return (
              <div
                key={deployment.id}
                className={`flex items-center gap-4 px-6 py-4 ${
                  index !== deployments.length - 1 ? "border-b" : ""
                }`}
              >
                <DIcon
                  className={`size-5 shrink-0 ${ds.color} ${deployment.status === "in-progress" ? "animate-spin" : ""}`}
                />
                <div className="flex min-w-0 flex-1 flex-col gap-1">
                  <p className="text-sm font-medium">{deployment.message}</p>
                  <div className="flex flex-wrap items-center gap-3 text-xs text-muted-foreground">
                    <Badge
                      variant="outline"
                      className="gap-1 px-1.5 py-0 text-xs font-normal"
                    >
                      <GitCommit className="size-3" />
                      {deployment.commit}
                    </Badge>
                    <Badge
                      variant="outline"
                      className="gap-1 px-1.5 py-0 text-xs font-normal"
                    >
                      <GitBranch className="size-3" />
                      {deployment.branch}
                    </Badge>
                    <span className="flex items-center gap-1">
                      <User className="size-3" />
                      {deployment.deployedBy}
                    </span>
                  </div>
                </div>
                <div className="flex flex-col items-end gap-1 text-right text-xs text-muted-foreground">
                  <Badge variant="secondary" className={`${ds.color} text-xs`}>
                    {ds.label}
                  </Badge>
                  <RelativeTime value={deployment.createdAt} fallback="never" />
                  {deployment.duration !== "-" && (
                    <span className="text-muted-foreground/70">
                      {deployment.duration}
                    </span>
                  )}
                </div>
              </div>
            )
          })}
        </CardContent>
      </Card>
    </div>
  )
}

function InfoStat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border bg-muted/20 p-4">
      <div className="text-muted-foreground text-xs uppercase tracking-wide">
        {label}
      </div>
      <div className="mt-2 text-sm font-medium break-all">{value}</div>
    </div>
  )
}

function PlaceholderSection({
  title,
  description,
}: {
  title: string
  description: string
}) {
  return (
    <div className="flex flex-1 flex-col items-center justify-center gap-3 p-12 text-center">
      <div className="flex size-12 items-center justify-center rounded-xl border bg-muted">
        <Settings className="size-6 text-muted-foreground" />
      </div>
      <div>
        <h3 className="font-semibold">{title}</h3>
        <p className="mt-1 text-sm text-muted-foreground">{description}</p>
      </div>
      <Button variant="outline" size="sm" disabled>
        Coming Soon
      </Button>
    </div>
  )
}

function containerStatusClassName(status: string) {
  switch (status) {
    case "running":
      return "border-green-500/40 text-green-600 dark:text-green-400"
    case "failed":
      return "border-red-500/40 text-red-600 dark:text-red-400"
    case "assigned":
    case "starting":
    case "created":
      return "border-yellow-500/40 text-yellow-600 dark:text-yellow-400"
    default:
      return "text-muted-foreground"
  }
}
