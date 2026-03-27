import React from 'react';
import { View } from 'react-native';

import { AppSidebar } from './app-sidebar';
import { useLargeScreen } from '@/hooks/use-large-screen';

interface SidebarLayoutProps {
  children: React.ReactNode;
}

/**
 * On large screens (iPads / desktops, width >= 768) renders the persistent
 * AppSidebar on the left exactly like the meshscale-ui web app.
 * On phones the children are rendered as-is, with no sidebar.
 */
export function SidebarLayout({ children }: SidebarLayoutProps) {
  const isLargeScreen = useLargeScreen();

  if (!isLargeScreen) {
    return <>{children}</>;
  }

  return (
    <View className="flex-1 flex-row">
      <AppSidebar />
      <View className="flex-1">
        {children}
      </View>
    </View>
  );
}
