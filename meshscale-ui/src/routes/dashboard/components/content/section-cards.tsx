import { useLiveQuery } from "dexie-react-hooks"
import { TrendingDown, TrendingUp, Activity, Server, Zap, CheckCircle2 } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import {
  Card,
  CardAction,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { db } from "@/lib/db"

export function SectionCards() {
  const projects = useLiveQuery(() => db.projects.toArray(), []) ?? []
  const deployments = useLiveQuery(() => db.deployments.toArray(), []) ?? []

  const activeCount = projects.filter((p) => p.status === "running").length
  const totalCount = projects.length

  const successfulDeploys = deployments.filter((d) => d.status === "success").length
  const failedDeploys = deployments.filter((d) => d.status === "failed").length
  const totalDeploys = deployments.length

  // Average uptime across running projects (parse "99.98%" → 99.98)
  const runningProjects = projects.filter(
    (p) => p.status === "running" && p.uptime !== "—"
  )
  const avgUptime =
    runningProjects.length > 0
      ? (
          runningProjects.reduce((sum, p) => {
            const val = parseFloat(p.uptime.replace("%", ""))
            return sum + (isNaN(val) ? 0 : val)
          }, 0) / runningProjects.length
        ).toFixed(2) + "%"
      : "—"

  return (
    <div className="grid grid-cols-1 gap-4 px-4 *:data-[slot=card]:bg-gradient-to-t *:data-[slot=card]:shadow-xs lg:px-6 @xl/main:grid-cols-2 @5xl/main:grid-cols-4">
      <Card className="@container/card">
        <CardHeader>
          <CardDescription className="flex items-center gap-1.5">
            <Server className="size-3.5" />
            Active Services
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
              {totalCount} total
            </Badge>
          </CardAction>
        </CardHeader>
        <CardFooter className="flex-col items-start gap-1.5 text-sm">
          <div className="line-clamp-1 flex gap-2 font-medium">
            {activeCount} running now
          </div>
          <div className="text-muted-foreground">
            Websites, APIs, and game servers
          </div>
        </CardFooter>
      </Card>

      <Card className="@container/card">
        <CardHeader>
          <CardDescription className="flex items-center gap-1.5">
            <CheckCircle2 className="size-3.5" />
            Deployments
          </CardDescription>
          <CardTitle className="text-2xl font-semibold tabular-nums @[250px]/card:text-3xl">
            {totalDeploys}
          </CardTitle>
          <CardAction>
            <Badge variant="outline">
              {failedDeploys > 0 ? <TrendingDown /> : <TrendingUp />}
              {successfulDeploys} succeeded
            </Badge>
          </CardAction>
        </CardHeader>
        <CardFooter className="flex-col items-start gap-1.5 text-sm">
          <div className="line-clamp-1 flex gap-2 font-medium">
            {failedDeploys} failed
          </div>
          <div className="text-muted-foreground">
            {successfulDeploys} successful deployments
          </div>
        </CardFooter>
      </Card>

      <Card className="@container/card">
        <CardHeader>
          <CardDescription className="flex items-center gap-1.5">
            <Zap className="size-3.5" />
            Avg. Uptime
          </CardDescription>
          <CardTitle className="text-2xl font-semibold tabular-nums @[250px]/card:text-3xl">
            {avgUptime}
          </CardTitle>
          <CardAction>
            <Badge variant="outline">
              <TrendingUp />
              running
            </Badge>
          </CardAction>
        </CardHeader>
        <CardFooter className="flex-col items-start gap-1.5 text-sm">
          <div className="line-clamp-1 flex gap-2 font-medium">
            Across {runningProjects.length} running service
            {runningProjects.length !== 1 ? "s" : ""}
          </div>
          <div className="text-muted-foreground">Based on reported uptime</div>
        </CardFooter>
      </Card>

      <Card className="@container/card">
        <CardHeader>
          <CardDescription className="flex items-center gap-1.5">
            <Activity className="size-3.5" />
            Control Plane
          </CardDescription>
          <CardTitle className="text-2xl font-semibold tabular-nums @[250px]/card:text-3xl">
            99.97%
          </CardTitle>
          <CardAction>
            <Badge variant="outline">
              <TrendingUp />
              +0.12%
            </Badge>
          </CardAction>
        </CardHeader>
        <CardFooter className="flex-col items-start gap-1.5 text-sm">
          <div className="line-clamp-1 flex gap-2 font-medium">
            Up 0.12% vs last month <TrendingUp className="size-4" />
          </div>
          <div className="text-muted-foreground">
            Compared to 99.85% last month
          </div>
        </CardFooter>
      </Card>
    </div>
  )
}
