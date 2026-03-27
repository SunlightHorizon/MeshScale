import { Link, useMatchRoute } from "@tanstack/react-router"
import { type LucideIcon } from "lucide-react"

import {
  SidebarGroup,
  SidebarGroupContent,
  SidebarGroupLabel,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar"

export function NavMain({
  items,
}: {
  items: {
    title: string
    url: string
    icon?: LucideIcon
  }[]
}) {
  const matchRoute = useMatchRoute()

  return (
    <SidebarGroup>
      <SidebarGroupContent>
        <SidebarGroupLabel>Home</SidebarGroupLabel>
        <SidebarMenu>
          {items.map((item) => {
            const isActive = !!matchRoute({ to: item.url as any, fuzzy: true })
            return (
              <SidebarMenuItem key={item.title}>
                <SidebarMenuButton
                  tooltip={item.title}
                  isActive={isActive}
                  className="data-[active=true]:ring-1 data-[active=true]:ring-border"
                  asChild
                >
                  <Link to={item.url as any}>
                    {item.icon && <item.icon />}
                    <span>{item.title}</span>
                  </Link>
                </SidebarMenuButton>
              </SidebarMenuItem>
            )
          })}
        </SidebarMenu>
      </SidebarGroupContent>
    </SidebarGroup>
  )
}
