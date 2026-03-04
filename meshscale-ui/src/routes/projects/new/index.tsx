import { createFileRoute } from '@tanstack/react-router'
import {
  SidebarInset,
  SidebarProvider,
} from "../../../components/ui/sidebar"
import { AppSidebar } from "../../dashboard/components/sidebar/app-sidebar"
import { CreateProjectForm } from "./components/create-project-form"

export const Route = createFileRoute('/projects/new/')({
  component: NewProject,
})

function NewProject() {
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
        <header className="bg-background/90 sticky top-0 z-10 flex h-(--header-height) shrink-0 items-center gap-2 border-b">
          <div className="flex w-full items-center gap-1 px-4 lg:gap-2 lg:px-6">
            <h1 className="text-base font-medium">Create New Project</h1>
          </div>
        </header>
        <div className="flex flex-1 flex-col overflow-y-auto">
          <CreateProjectForm />
        </div>
      </SidebarInset>
    </SidebarProvider>
  )
}
