import { Link } from "@tanstack/react-router"
import {
  Globe,
  Gamepad2,
  Code2,
  Cpu,
  Clock,
  MoreVertical,
  MapPin,
  Zap,
} from "lucide-react"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import type { Project, ProjectType, ProjectStatus } from "../data"

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
  api: {
    icon: Code2,
    label: "API",
    color: "text-green-500 bg-green-500/10",
  },
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

export function ProjectsList({ projects }: { projects: Project[] }) {
  return (
    <div className="flex flex-1 flex-col gap-6 p-4 lg:p-6">
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {projects.map((project) => {
          const type = typeConfig[project.type]
          const status = statusConfig[project.status]
          const TypeIcon = type.icon

          return (
            <Card
              key={project.id}
              className="group flex flex-col transition-shadow hover:shadow-md"
            >
              <CardHeader className="pb-3">
                <div className="flex items-start justify-between">
                  <div className="flex flex-1 items-start gap-3">
                    <div
                      className={`mt-0.5 flex size-9 shrink-0 items-center justify-center rounded-lg ${type.color}`}
                    >
                      <TypeIcon className="size-4" />
                    </div>
                    <div className="min-w-0 flex-1">
                      <Link
                        to="/projects/$projectId"
                        params={{ projectId: project.id }}
                        className="hover:underline"
                      >
                        <CardTitle className="truncate text-base leading-snug">
                          {project.name}
                        </CardTitle>
                      </Link>
                      <CardDescription className="mt-0.5 line-clamp-2 text-xs">
                        {project.description}
                      </CardDescription>
                    </div>
                  </div>
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <Button
                        variant="ghost"
                        size="icon"
                        className="size-7 shrink-0 opacity-0 transition-opacity group-hover:opacity-100"
                        onClick={(e) => e.preventDefault()}
                      >
                        <MoreVertical className="size-3.5" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end">
                      <DropdownMenuItem>Redeploy</DropdownMenuItem>
                      <DropdownMenuItem>View Logs</DropdownMenuItem>
                      <DropdownMenuItem>Edit Settings</DropdownMenuItem>
                      <DropdownMenuSeparator />
                      {project.status === "running" ? (
                        <DropdownMenuItem>Stop</DropdownMenuItem>
                      ) : (
                        <DropdownMenuItem>Start</DropdownMenuItem>
                      )}
                      <DropdownMenuSeparator />
                      <DropdownMenuItem className="text-red-600">
                        Delete
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                </div>
              </CardHeader>

              <CardContent className="flex flex-1 flex-col gap-4 pt-0">
                {/* Status + Type badges */}
                <div className="flex items-center gap-2">
                  <Badge
                    variant="secondary"
                    className={`flex items-center gap-1.5 px-2 py-0.5 text-xs font-medium ${status.badge}`}
                  >
                    <span className={`size-1.5 rounded-full ${status.dot}`} />
                    {status.label}
                  </Badge>
                  <Badge
                    variant="outline"
                    className="px-2 py-0.5 text-xs text-muted-foreground"
                  >
                    {type.label}
                  </Badge>
                </div>

                {/* Stats row */}
                <div className="grid grid-cols-2 gap-2 text-xs">
                  <div className="flex items-center gap-1.5 text-muted-foreground">
                    <MapPin className="size-3 shrink-0" />
                    <span className="truncate">{project.region}</span>
                  </div>
                  <div className="flex items-center gap-1.5 text-muted-foreground">
                    <Zap className="size-3 shrink-0" />
                    <span>{project.uptime} uptime</span>
                  </div>
                </div>

                {/* Resource usage */}
                {project.status === "running" && (
                  <div className="space-y-2 text-xs">
                    <div className="flex items-center justify-between text-muted-foreground">
                      <span>CPU</span>
                      <span className="font-medium tabular-nums text-foreground">
                        {project.cpu}%
                      </span>
                    </div>
                    <div className="h-1.5 w-full overflow-hidden rounded-full bg-muted">
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
                    <div className="flex items-center justify-between text-muted-foreground">
                      <span>Memory</span>
                      <span className="font-medium tabular-nums text-foreground">
                        {project.memory}%
                      </span>
                    </div>
                    <div className="h-1.5 w-full overflow-hidden rounded-full bg-muted">
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
                )}

                {/* Footer */}
                <div className="mt-auto flex items-center justify-between border-t pt-3 text-xs text-muted-foreground">
                  <span>
                    {project.instances > 0
                      ? `${project.instances} instance${project.instances !== 1 ? "s" : ""}`
                      : "No instances"}
                  </span>
                  <span>Deployed {project.lastDeployed}</span>
                </div>

                {/* View button */}
                <Link
                  to="/projects/$projectId"
                  params={{ projectId: project.id }}
                  className="block"
                >
                  <Button variant="outline" size="sm" className="w-full">
                    View Project
                  </Button>
                </Link>
              </CardContent>
            </Card>
          )
        })}
      </div>
    </div>
  )
}
