import {
  Activity,
  CheckCircle2,
  Server,
  TrendingDown,
  TrendingUp,
  Waypoints,
  Zap,
} from "lucide-react"
import { Badge } from "@/components/ui/badge"
import {
  Card,
  CardAction,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import type { ControlPlaneStatusSnapshot } from "@/lib/api"
import type { Deployment, Project } from "@/routes/projects/data"

interface SectionCardsProps {
  snapshot: ControlPlaneStatusSnapshot | null
  projects: Project[]
  deployments: Deployment[]
}

export function SectionCards({
  snapshot,
  projects,
  deployments,
}: SectionCardsProps) {
  const activeCount = projects.filter((project) => project.status === "running").length
  const totalCount = projects.length
  const totalApps = projects.reduce(
    (sum, project) => sum + (project.appCount ?? project.apps?.length ?? 0),
    0,
  )
  const successfulDeploys = deployments.filter(
    (deployment) => deployment.status === "success",
  ).length
  const failedDeploys = deployments.filter(
    (deployment) => deployment.status === "failed",
  ).length
  const totalDesiredReplicas = projects.reduce(
    (sum, project) => sum + (project.desiredInstances ?? project.instances),
    0,
  )
  const runningReplicas = projects.reduce(
    (sum, project) => sum + project.instances,
    0,
  )
  const connectedWorkers = snapshot?.workers.filter(
    (worker) => worker.status !== "offline",
  ).length ?? 0
  const totalWorkers = snapshot?.workers.length ?? 0
  const assignedContainers = snapshot?.assignments.length ?? 0

  return (
    <div className="grid grid-cols-1 gap-4 px-4 *:data-[slot=card]:bg-gradient-to-t *:data-[slot=card]:shadow-xs lg:px-6 @xl/main:grid-cols-2 @5xl/main:grid-cols-4">
      <Card className="@container/card">
        <CardHeader>
          <CardDescription className="flex items-center gap-1.5">
            <Server className="size-3.5" />
            Active Projects
          </CardDescription>
          <CardTitle className="text-2xl font-semibold tabular-nums @[250px]/card:text-3xl">
            {activeCount}
            <span className="text-muted-foreground text-xl font-normal @[250px]/card:text-2xl">
              /{totalCount}
            </span>
          </CardTitle>
          <CardAction>
            <Badge variant="outline">
              <TrendingUp />
              {totalApps} apps
            </Badge>
          </CardAction>
        </CardHeader>
        <CardFooter className="flex-col items-start gap-1.5 text-sm">
          <div className="line-clamp-1 flex gap-2 font-medium">
            {activeCount} project{activeCount !== 1 ? "s" : ""} running now
          </div>
          <div className="text-muted-foreground">
            One deployed Swift app becomes one project card
          </div>
        </CardFooter>
      </Card>

      <Card className="@container/card">
        <CardHeader>
          <CardDescription className="flex items-center gap-1.5">
            <CheckCircle2 className="size-3.5" />
            Rollouts
          </CardDescription>
          <CardTitle className="text-2xl font-semibold tabular-nums @[250px]/card:text-3xl">
            {deployments.length}
          </CardTitle>
          <CardAction>
            <Badge variant="outline">
              {failedDeploys > 0 ? <TrendingDown /> : <TrendingUp />}
              {successfulDeploys} healthy
            </Badge>
          </CardAction>
        </CardHeader>
        <CardFooter className="flex-col items-start gap-1.5 text-sm">
          <div className="line-clamp-1 flex gap-2 font-medium">
            {failedDeploys} failing rollout{failedDeploys !== 1 ? "s" : ""}
          </div>
          <div className="text-muted-foreground">
            One current rollout summary per project
          </div>
        </CardFooter>
      </Card>

      <Card className="@container/card">
        <CardHeader>
          <CardDescription className="flex items-center gap-1.5">
            <Zap className="size-3.5" />
            Replica Coverage
          </CardDescription>
          <CardTitle className="text-2xl font-semibold tabular-nums @[250px]/card:text-3xl">
            {runningReplicas}
            <span className="text-muted-foreground text-xl font-normal @[250px]/card:text-2xl">
              /{totalDesiredReplicas}
            </span>
          </CardTitle>
          <CardAction>
            <Badge variant="outline">
              <TrendingUp />
              {assignedContainers} assigned
            </Badge>
          </CardAction>
        </CardHeader>
        <CardFooter className="flex-col items-start gap-1.5 text-sm">
          <div className="line-clamp-1 flex gap-2 font-medium">
            {totalDesiredReplicas === 0
              ? "No replicas requested yet"
              : `${runningReplicas} of ${totalDesiredReplicas} replicas online`}
          </div>
          <div className="text-muted-foreground">
            Derived from worker-reported container state
          </div>
        </CardFooter>
      </Card>

      <Card className="@container/card">
        <CardHeader>
          <CardDescription className="flex items-center gap-1.5">
            <Activity className="size-3.5" />
            Workers
          </CardDescription>
          <CardTitle className="text-2xl font-semibold tabular-nums @[250px]/card:text-3xl">
            {connectedWorkers}
            <span className="text-muted-foreground text-xl font-normal @[250px]/card:text-2xl">
              /{totalWorkers}
            </span>
          </CardTitle>
          <CardAction>
            <Badge variant="outline">
              <Waypoints />
              {snapshot?.domain ?? "local dev"}
            </Badge>
          </CardAction>
        </CardHeader>
        <CardFooter className="flex-col items-start gap-1.5 text-sm">
          <div className="line-clamp-1 flex gap-2 font-medium">
            {connectedWorkers} worker{connectedWorkers !== 1 ? "s" : ""} connected
          </div>
          <div className="text-muted-foreground">
            Regions and health are coming from the control plane API
          </div>
        </CardFooter>
      </Card>
    </div>
  )
}
