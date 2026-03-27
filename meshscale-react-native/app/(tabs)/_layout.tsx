import { Tabs } from 'expo-router';
import React from 'react';
import { View } from 'react-native';
import { LayoutDashboard, Folder, Settings } from 'lucide-react-native';

import { HapticTab } from '@/components/layout/haptic-tab';
import { AppSidebar } from '@/components/layout/app-sidebar';
import { Colors } from '@/constants/theme';
import { useColorScheme } from '@/hooks/use-color-scheme';
import { useLargeScreen } from '@/hooks/use-large-screen';

export default function TabLayout() {
  const colorScheme = useColorScheme();
  const isLargeScreen = useLargeScreen();

  return (
    <View className="flex flex-1 flex-row">
      {isLargeScreen && <AppSidebar />}

      <View className="flex-1">
        <Tabs
          screenOptions={{
            tabBarActiveTintColor: Colors[colorScheme ?? 'light'].tint,
            headerShown: false,
            tabBarButton: HapticTab,
            tabBarStyle: isLargeScreen ? { display: 'none' } : undefined,
          }}
        >
          <Tabs.Screen
            name="index"
            options={{
              title: 'Dashboard',
              tabBarIcon: ({ color }) => <LayoutDashboard size={24} color={color} />,
            }}
          />
          <Tabs.Screen
            name="projects"
            options={{
              title: 'Projects',
              tabBarIcon: ({ color }) => <Folder size={24} color={color} />,
            }}
          />
          <Tabs.Screen
            name="settings"
            options={{
              title: 'Settings',
              tabBarIcon: ({ color }) => <Settings size={24} color={color} />,
            }}
          />
        </Tabs>
      </View>
    </View>
  );
}
