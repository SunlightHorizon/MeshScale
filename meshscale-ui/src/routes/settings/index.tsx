import { createFileRoute } from '@tanstack/react-router'
import {
  SidebarInset,
  SidebarProvider,
} from "../../components/ui/sidebar"
import { AppSidebar } from "../dashboard/components/sidebar/app-sidebar"
import { SettingsHeader } from "./components/settings-header"
import { SettingsContent } from "./components/settings-content"

export const Route = createFileRoute('/settings/')({
  component: Settings,
})

function Settings() {
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
        <SettingsHeader />
        <div className="flex flex-1 flex-col overflow-y-auto">
          <SettingsContent />
        </div>
      </SidebarInset>
    </SidebarProvider>
  )
}
