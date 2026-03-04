import { Link } from "@tanstack/react-router"
import { Plus } from "lucide-react"
import { Button } from "@/components/ui/button"

export function ProjectsHeader() {
  return (
    <header className="bg-background/90 sticky top-0 z-10 flex h-(--header-height) shrink-0 items-center gap-2 border-b transition-[width,height] ease-linear group-has-data-[collapsible=icon]/sidebar-wrapper:h-(--header-height)">
      <div className="flex w-full items-center gap-1 px-4 lg:gap-2 lg:px-6">
        <h1 className="text-base font-medium">Projects</h1>
        <div className="ml-auto flex items-center gap-2">
          <Link to="/projects/new">
            <Button size="sm">
              <Plus />
              <span>New Project</span>
            </Button>
          </Link>
        </div>
      </div>
    </header>
  )
}
import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/projects/components/projects-header')({
  component: RouteComponent,
})

function RouteComponent() {
  return <div>Hello "/projects/components/projects-header"!</div>
}
