import React from 'react';
import {
  Layers,
  Folder,
  List,
  BarChart2,
  Users,
  Settings,
  HelpCircle,
  Search,
  Database,
  FileText,
  Sparkles,
  MoreHorizontal,
  MoreVertical,
  LayoutDashboard,
} from 'lucide-react-native';
import { usePathname, router } from 'expo-router';
import { Alert, Text } from 'react-native';
import { useColorScheme } from 'nativewind';

import {
  Sidebar,
  SidebarContent,
  SidebarGroup,
  SidebarGroupLabel,
  SidebarHeader,
  SidebarFooter,
  SidebarMenu,
  SidebarMenuItem,
  SidebarMenuButton,
} from '@/components/ui/sidebar';
import { getIconColor, type ColorScheme } from '@/theme/tokens';

export const SIDEBAR_WIDTH = 256;

type IconComponent = React.ComponentType<{ size?: number; color?: string; strokeWidth?: number }>;

const NAV_MAIN: { title: string; Icon: IconComponent; url: string | null }[] = [
  { title: 'Dashboard', Icon: LayoutDashboard, url: '/' },
  { title: 'Projects', Icon: Folder, url: '/projects' },
  { title: 'Lifecycle', Icon: List, url: null },
  { title: 'Analytics', Icon: BarChart2, url: null },
  { title: 'Team', Icon: Users, url: null },
];

const NAV_DOCUMENTS: { name: string; Icon: IconComponent }[] = [
  { name: 'Data Library', Icon: Database },
  { name: 'Reports', Icon: FileText },
  { name: 'Word Assistant', Icon: Sparkles },
];

const NAV_SECONDARY: { title: string; Icon: IconComponent; url: string | null }[] = [
  { title: 'Settings', Icon: Settings, url: '/settings' },
  { title: 'Get Help', Icon: HelpCircle, url: null },
  { title: 'Search', Icon: Search, url: null },
];

export function AppSidebar() {
  const { colorScheme } = useColorScheme();
  const pathname = usePathname();
  const scheme = (colorScheme === 'dark' ? 'dark' : 'light') as ColorScheme;

  const isActive = (url: string | null) => {
    if (!url) return false;
    if (url === '/') return pathname === '/' || pathname === '';
    return pathname.startsWith(url);
  };

  const navigate = (url: string) => router.navigate(url as any);

  return (
    <Sidebar>
      {/* Header */}
      <SidebarHeader>
        <Layers
          size={20}
          color={getIconColor('sidebar', scheme)}
          strokeWidth={2}
        />
        <Text className="text-base font-semibold text-sidebar-foreground">
          Mesh Scale
        </Text>
      </SidebarHeader>

      {/* Main Navigation */}
      <SidebarContent>
        <SidebarGroup>
          <SidebarGroupLabel>Home</SidebarGroupLabel>
          <SidebarMenu>
            {NAV_MAIN.map((item) => (
              <SidebarMenuItem key={item.title}>
                <SidebarMenuButton
                  isActive={isActive(item.url)}
                  disabled={!item.url}
                  onPress={() => item.url && navigate(item.url)}
                >
                  <item.Icon
                    size={16}
                    color={
                      isActive(item.url)
                        ? getIconColor('sidebarAccentForeground', scheme)
                        : getIconColor('mutedForeground', scheme)
                    }
                    strokeWidth={2}
                  />
                  <Text
                    className={`text-sm font-normal text-muted-foreground ${
                      isActive(item.url)
                        ? 'font-medium text-sidebar-accent-foreground'
                        : ''
                    }`}
                  >
                    {item.title}
                  </Text>
                </SidebarMenuButton>
              </SidebarMenuItem>
            ))}
          </SidebarMenu>
        </SidebarGroup>

        {/* Documents */}
        <SidebarGroup>
          <SidebarGroupLabel>Documents</SidebarGroupLabel>
          <SidebarMenu>
            {NAV_DOCUMENTS.map((doc) => (
              <SidebarMenuItem key={doc.name}>
                <SidebarMenuButton disabled>
                  <doc.Icon
                    size={16}
                    color={getIconColor('mutedForeground', scheme)}
                    strokeWidth={2}
                  />
                  <Text className="text-sm font-normal text-muted-foreground flex-1">
                    {doc.name}
                  </Text>
                </SidebarMenuButton>
              </SidebarMenuItem>
            ))}
            <SidebarMenuItem>
              <SidebarMenuButton
                disabled
                onPress={() =>
                  Alert.alert('More', 'Additional documents', [
                    { text: 'OK', style: 'cancel' },
                  ])
                }
              >
                <MoreHorizontal
                  size={16}
                  color={getIconColor('mutedForeground', scheme)}
                  strokeWidth={2}
                />
                <Text className="text-sm font-normal text-muted-foreground">
                  More
                </Text>
              </SidebarMenuButton>
            </SidebarMenuItem>
          </SidebarMenu>
        </SidebarGroup>

        {/* Secondary Navigation */}
        <SidebarGroup>
          <SidebarMenu>
            {NAV_SECONDARY.map((item) => (
              <SidebarMenuItem key={item.title}>
                <SidebarMenuButton
                  isActive={isActive(item.url)}
                  disabled={!item.url}
                  onPress={() => item.url && navigate(item.url)}
                >
                  <item.Icon
                    size={16}
                    color={
                      isActive(item.url)
                        ? getIconColor('sidebarAccentForeground', scheme)
                        : getIconColor('mutedForeground', scheme)
                    }
                    strokeWidth={2}
                  />
                  <Text
                    className={`text-sm font-normal text-muted-foreground ${
                      isActive(item.url)
                        ? 'font-medium text-sidebar-accent-foreground'
                        : ''
                    }`}
                  >
                    {item.title}
                  </Text>
                </SidebarMenuButton>
              </SidebarMenuItem>
            ))}
          </SidebarMenu>
        </SidebarGroup>
      </SidebarContent>

      {/* Footer - User Profile */}
      <SidebarFooter>
        <SidebarMenuButton
          onPress={() =>
            Alert.alert('shadcn', 'm@example.com', [
              { text: 'Account' },
              { text: 'Billing' },
              { text: 'Notifications' },
              { text: 'Log out', style: 'destructive' },
              { text: 'Cancel', style: 'cancel' },
            ])
          }
        >
          <Text className="text-xs font-bold text-sidebar-primary w-8 h-8 rounded-lg bg-sidebar-accent items-center justify-center text-center leading-8">
            CN
          </Text>
          <Text className="text-sm font-medium text-sidebar-foreground flex-1">
            shadcn
          </Text>
          <MoreVertical
            size={16}
            color={getIconColor('mutedForeground', scheme)}
            strokeWidth={2}
          />
        </SidebarMenuButton>
      </SidebarFooter>
    </Sidebar>
  );
}
