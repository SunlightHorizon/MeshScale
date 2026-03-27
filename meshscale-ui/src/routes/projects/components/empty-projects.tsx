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
        <h2 className="mt-6 text-xl font-semibold">No deployments yet</h2>
        <p className="text-muted-foreground mt-2 text-sm">
          Deploy your first project — a website, game server, API, or background
          worker. Get up and running in minutes.
        </p>
        <Link to="/projects/new" className="mt-6">
          <Button size="lg">
            <Plus />
            Deploy Your First Project
          </Button>
        </Link>
      </div>
    </div>
  )
}

