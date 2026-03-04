import { createFileRoute } from "@tanstack/react-router";
import {
  SidebarInset,
  SidebarProvider,
} from "../../components/ui/sidebar"
import { AppSidebar } from "./components/sidebar/app-sidebar"
import { ChartAreaInteractive } from "./components/content/chart-area-interactive"
import { DataTable } from "./components/content/data-table"
import { SectionCards } from "./components/content/section-cards"
import { SiteHeader } from "./components/content/site-header"
import { CostBreakdown } from "./components/content/cost-breakdown"

import data from "./data.json"

export const Route = createFileRoute("/dashboard/")({ component: App });

function App() {
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
        <SiteHeader />
        <div className="flex flex-1 flex-col overflow-y-auto">
          <div className="@container/main flex flex-1 flex-col gap-2">
            <div className="flex flex-col gap-4 py-4 md:gap-6 md:py-6">
              <SectionCards />
              <div className="grid gap-4 px-4 lg:grid-cols-3 lg:items-start lg:px-6">
                <div className="lg:col-span-2">
                  <ChartAreaInteractive />
                </div>
                <div className="lg:col-span-1 lg:h-full">
                  <CostBreakdown />
                </div>
              </div>
              <DataTable data={data} />
            </div>
          </div>
        </div>
      </SidebarInset>
    </SidebarProvider>
  );
}
