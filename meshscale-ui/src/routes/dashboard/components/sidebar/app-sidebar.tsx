import * as React from "react"
import { Link } from "@tanstack/react-router"
import {
  BarChart3,
  LayoutDashboard,
  Database,
  FileType,
  Folder,
  HelpCircle,
  Layers,
  ListTodo,
  FileBarChart,
  Search,
  Settings,
  Users,
} from "lucide-react"

import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar"
import { NavDocuments } from "@/routes/dashboard/components/sidebar/nav-documents"
import { NavMain } from "@/routes/dashboard/components/sidebar/nav-main"
import { NavSecondary } from "@/routes/dashboard/components/sidebar/nav-secondary"
import { NavUser } from "@/routes/dashboard/components/sidebar/nav-user"

const data = {
  user: {
    name: "shadcn",
    email: "m@example.com",
    avatar: "/avatars/shadcn.jpg",
  },
  navMain: [
    {
      title: "Dashboard",
      url: "/dashboard",
      icon: LayoutDashboard,
    },
    {
      title: "Projects",
      url: "/projects",
      icon: Folder,
    },
    {
      title: "Lifecycle",
      url: "#",
      icon: ListTodo,
    },
    {
      title: "Analytics",
      url: "#",
      icon: BarChart3,
    },
    {
      title: "Team",
      url: "#",
      icon: Users,
    },
  ],
  navSecondary: [
    {
      title: "Settings",
      url: "/settings",
      icon: Settings,
    },
    {
      title: "Get Help",
      url: "#",
      icon: HelpCircle,
    },
    {
      title: "Search",
      url: "#",
      icon: Search,
    },
  ],
  documents: [
    {
      name: "Data Library",
      url: "#",
      icon: Database,
    },
    {
      name: "Reports",
      url: "#",
      icon: FileBarChart,
    },
    {
      name: "Word Assistant",
      url: "#",
      icon: FileType,
    },
  ],
}

export function AppSidebar({ ...props }: React.ComponentProps<typeof Sidebar>) {
  return (
    <Sidebar collapsible="none" className="flex h-screen flex-col border-r" {...props}>
      <SidebarHeader className="border-b">
        <SidebarMenu>
          <SidebarMenuItem>
            <SidebarMenuButton
              asChild
              className="data-[slot=sidebar-menu-button]:!p-1.5"
            >
              <Link to="/">
                <Layers className="!size-5" />
                <span className="text-base font-semibold">Mesh Scale</span>
              </Link>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarHeader>
      <SidebarContent className="flex-1 overflow-y-auto">
        <NavMain items={data.navMain} />
        <NavDocuments items={data.documents} />
        <NavSecondary items={data.navSecondary} className="mt-auto" />
      </SidebarContent>
      <SidebarFooter className="border-t">
        <NavUser user={data.user} />
      </SidebarFooter>
    </Sidebar>
  )
}
