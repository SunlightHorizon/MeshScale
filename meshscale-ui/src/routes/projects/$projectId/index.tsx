import { createFileRoute, Link, notFound } from "@tanstack/react-router"
import { useState } from "react"
import { useLiveQuery } from "dexie-react-hooks"
import {
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
import { db } from "@/lib/db"
import type {
  Project,
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
  | "deployments"
  | "logs"
  | "environment"
  | "settings"

const typeConfig: Record<
  ProjectType,
  { icon: React.ElementType; label: string; color: string }
> = {
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
    { id: "deployments", label: "Deployments", icon: Rocket },
    { id: "logs", label: "Logs", icon: ScrollText },
    { id: "environment", label: "Environment", icon: KeyRound },
    { id: "settings", label: "Settings", icon: Settings },
  ]

function ProjectDetail() {
  const { projectId } = Route.useParams()
  const [activeSection, setActiveSection] = useState<NavSection>("overview")

  const project = useLiveQuery(
    () => db.projects.get(projectId),
    [projectId]
  )
  const deployments = useLiveQuery(
    () =>
      db.deployments
        .where("projectId")
        .equals(projectId)
        .reverse()
        .sortBy("id"),
    [projectId]
  ) ?? []

  // Still loading
  if (project === undefined) {
    return (
      <div className="flex h-screen items-center justify-center">
        <Loader2 className="size-5 animate-spin text-muted-foreground" />
      </div>
    )
  }

  // Not found
  if (project === null) {
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
                <span className="font-medium text-foreground">Instances</span>
                <div className="flex items-center gap-1.5">
                  <Server className="size-3" />
                  {project.instances > 0
                    ? `${project.instances} running`
                    : "None running"}
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
            </div>
          </aside>

          {/* Main content */}
          <main className="flex-1 overflow-y-auto">
            {activeSection === "overview" && (
              <OverviewSection project={project} deployments={deployments} />
            )}
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
  deployments,
}: {
  project: Project
  deployments: Deployment[]
}) {
  const status = statusConfig[project.status]

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
              CPU Usage
            </CardDescription>
            <CardTitle className="text-xl tabular-nums">
              {project.status === "running" ? `${project.cpu}%` : "—"}
            </CardTitle>
          </CardHeader>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardDescription className="flex items-center gap-1.5">
              <MemoryStick className="size-3.5" />
              Memory
            </CardDescription>
            <CardTitle className="text-xl tabular-nums">
              {project.status === "running" ? `${project.memory}%` : "—"}
            </CardTitle>
          </CardHeader>
        </Card>
      </div>

      {/* Resource bars */}
      {project.status === "running" && (
        <Card>
          <CardHeader>
            <CardTitle className="text-sm font-medium">
              Resource Usage
            </CardTitle>
            <CardDescription>
              Live resource utilization across {project.instances} instance
              {project.instances !== 1 ? "s" : ""}
            </CardDescription>
          </CardHeader>
          <CardContent className="flex flex-col gap-4">
            <div className="space-y-2">
              <div className="flex items-center justify-between text-sm">
                <span className="text-muted-foreground">CPU</span>
                <span className="font-medium tabular-nums">{project.cpu}%</span>
              </div>
              <div className="h-2 w-full overflow-hidden rounded-full bg-muted">
                <div
                  className={`h-full rounded-full transition-all ${
                    project.cpu > 80
                      ? "bg-red-500"
                      : project.cpu > 60
                        ? "bg-yellow-500"
                        : "bg-green-500"
                  }`}
                  style={{ width: `${project.cpu}%` }}
                />
              </div>
            </div>
            <div className="space-y-2">
              <div className="flex items-center justify-between text-sm">
                <span className="text-muted-foreground">Memory</span>
                <span className="font-medium tabular-nums">
                  {project.memory}%
                </span>
              </div>
              <div className="h-2 w-full overflow-hidden rounded-full bg-muted">
                <div
                  className={`h-full rounded-full transition-all ${
                    project.memory > 80
                      ? "bg-red-500"
                      : project.memory > 60
                        ? "bg-yellow-500"
                        : "bg-blue-500"
                  }`}
                  style={{ width: `${project.memory}%` }}
                />
              </div>
            </div>
          </CardContent>
        </Card>
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
                  <span>{deployment.createdAt}</span>
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
                  <span>{deployment.createdAt}</span>
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
