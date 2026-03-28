import { createFileRoute } from '@tanstack/react-router'
import {
  SidebarInset,
  SidebarProvider,
} from "../../components/ui/sidebar"
import { useControlPlaneData } from "@/hooks/use-control-plane-data"
import { AppSidebar } from "../dashboard/components/sidebar/app-sidebar"
import { ProjectsHeader } from "./components/projects-header"
import { ProjectsContent } from "./components/projects-content"

export const Route = createFileRoute('/projects/')({
  component: Projects,
})

function Projects() {
  const { projects, isLoading, error, refetch } = useControlPlaneData()

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
        <ProjectsHeader />
        <div className="flex flex-1 flex-col overflow-y-auto">
          <ProjectsContent
            projects={projects}
            isLoading={isLoading}
            error={error}
            onRetry={refetch}
          />
        </div>
      </SidebarInset>
    </SidebarProvider>
  )
}
