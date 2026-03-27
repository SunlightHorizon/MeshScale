import { useLiveQuery } from "dexie-react-hooks"
import { db } from "@/lib/db"
import { ProjectsList } from "./projects-list"
import { EmptyProjects } from "./empty-projects"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"

export function ProjectsContent() {
  const projects = useLiveQuery(() => db.projects.toArray(), []) ?? []

  const running = projects.filter((p) => p.status === "running")
  const deploying = projects.filter((p) => p.status === "deploying")
  const inactive = projects.filter(
    (p) => p.status === "stopped" || p.status === "error"
  )

  if (projects.length === 0) {
    return <EmptyProjects />
  }

  return (
    <div className="flex flex-1 flex-col">
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
