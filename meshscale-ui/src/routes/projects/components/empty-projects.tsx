import { Link } from "@tanstack/react-router"
import { FolderOpen, Plus } from "lucide-react"
import { Button } from "@/components/ui/button"

export function EmptyProjects() {
  return (
    <div className="flex flex-1 items-center justify-center p-4">
      <div className="flex max-w-md flex-col items-center text-center">
        <div className="bg-muted flex size-20 items-center justify-center rounded-full">
          <FolderOpen className="text-muted-foreground size-10" />
        </div>
        <h2 className="mt-6 text-xl font-semibold">No projects yet</h2>
        <p className="text-muted-foreground mt-2 text-sm">
          Get started by creating your first project. Projects help you organize
          and track your work.
        </p>
        <Link to="/projects/new" className="mt-6">
          <Button size="lg">
            <Plus />
            Create Your First Project
          </Button>
        </Link>
      </div>
    </div>
  )
}
import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/projects/components/empty-projects')({
  component: RouteComponent,
})

function RouteComponent() {
  return <div>Hello "/projects/components/empty-projects"!</div>
}
