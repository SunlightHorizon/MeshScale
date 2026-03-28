import { AlertCircle, Loader2 } from "lucide-react"
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert"
import { Button } from "@/components/ui/button"
import { ProjectsList } from "./projects-list"
import { EmptyProjects } from "./empty-projects"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import type { Project } from "../data"

interface ProjectsContentProps {
  projects: Project[]
  isLoading: boolean
  error: string | null
  onRetry: () => Promise<void>
}

export function ProjectsContent({
  projects,
  isLoading,
  error,
  onRetry,
}: ProjectsContentProps) {

  const running = projects.filter((p) => p.status === "running")
  const deploying = projects.filter((p) => p.status === "deploying")
  const inactive = projects.filter(
    (p) => p.status === "stopped" || p.status === "error"
  )

  if (isLoading && projects.length === 0) {
    return (
      <div className="flex flex-1 items-center justify-center">
        <div className="flex items-center gap-2 text-sm text-muted-foreground">
          <Loader2 className="size-4 animate-spin" />
          Loading control-plane projects...
        </div>
      </div>
    )
  }

  if (error && projects.length === 0) {
    return (
      <div className="p-4 lg:p-6">
        <Alert variant="destructive">
          <AlertCircle className="size-4" />
          <AlertTitle>Control plane unavailable</AlertTitle>
          <AlertDescription>
            <p>{error}</p>
            <Button
              variant="outline"
              size="sm"
              onClick={() => void onRetry()}
              className="mt-2"
            >
              Retry
            </Button>
          </AlertDescription>
        </Alert>
      </div>
    )
  }

  if (projects.length === 0) {
    return <EmptyProjects />
  }

  return (
    <div className="flex flex-1 flex-col">
      {error && (
        <div className="px-4 pt-4 lg:px-6 lg:pt-6">
          <Alert variant="destructive">
            <AlertCircle className="size-4" />
            <AlertTitle>Showing the last known project state</AlertTitle>
            <AlertDescription>
              <p>{error}</p>
            </AlertDescription>
          </Alert>
        </div>
      )}
      <Tabs defaultValue="all" className="flex flex-1 flex-col">
        <div className="border-b px-4 py-2 lg:px-6">
          <TabsList>
            <TabsTrigger value="all">All ({projects.length})</TabsTrigger>
            <TabsTrigger value="running">
              Running ({running.length})
            </TabsTrigger>
            {deploying.length > 0 && (
              <TabsTrigger value="deploying">
                Deploying ({deploying.length})
              </TabsTrigger>
            )}
            <TabsTrigger value="inactive">
              Inactive ({inactive.length})
            </TabsTrigger>
          </TabsList>
        </div>
        <TabsContent value="all" className="flex-1">
          <ProjectsList projects={projects} />
        </TabsContent>
        <TabsContent value="running" className="flex-1">
          <ProjectsList projects={running} />
        </TabsContent>
        {deploying.length > 0 && (
          <TabsContent value="deploying" className="flex-1">
            <ProjectsList projects={deploying} />
          </TabsContent>
        )}
        <TabsContent value="inactive" className="flex-1">
          <ProjectsList projects={inactive} />
        </TabsContent>
      </Tabs>
    </div>
  )
}
