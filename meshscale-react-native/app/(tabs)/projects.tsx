// ─── Projects Screen ─────────────────────────────────────────────────────────
// Lists all projects with filtering, responsive grid, and empty state.

import React, { useState } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  useWindowDimensions,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Plus } from 'lucide-react-native';
import { router } from 'expo-router';
import { cn } from '@/lib/tailwind-utils';

import { useStore } from '@/lib/store';
import { useLargeScreen } from '@/hooks/use-large-screen';
import { Button } from '@/components/ui/button';
import { SIDEBAR_WIDTH } from '@/components/layout/app-sidebar';
import { ProjectCard } from '@/features/projects/project-card';
import { ProjectFilters, FilterTab } from '@/features/projects/project-filters';
import { ProjectEmptyState } from '@/features/projects/project-empty-state';

export default function ProjectsScreen() {
  const { projects } = useStore();
  const [activeTab, setActiveTab] = useState<FilterTab>('all');
  const isLargeScreen = useLargeScreen();
  const { width } = useWindowDimensions();

  // ─── Layout math ───────────────────────────────────────────────────────────
  const numColumns = width >= 1024 ? 3 : isLargeScreen ? 2 : 1;
  const LIST_PADDING = 16;
  const CARD_GAP = 16;
  const contentWidth = width - (isLargeScreen ? SIDEBAR_WIDTH : 0) - LIST_PADDING * 2;
  const cardWidth =
    numColumns > 1
      ? (contentWidth - CARD_GAP * (numColumns - 1)) / numColumns
      : undefined;

  // ─── Filtering ─────────────────────────────────────────────────────────────
  const running = projects.filter(p => p.status === 'running');
  const deploying = projects.filter(p => p.status === 'deploying');
  const inactive = projects.filter(p => p.status === 'stopped' || p.status === 'error');

  const filtered =
    activeTab === 'all'
      ? projects
      : activeTab === 'running'
        ? running
        : activeTab === 'deploying'
          ? deploying
          : inactive;

  const tabs = [
    { id: 'all' as FilterTab, label: 'All', count: projects.length },
    { id: 'running' as FilterTab, label: 'Running', count: running.length },
    ...(deploying.length > 0
      ? [{ id: 'deploying' as FilterTab, label: 'Deploying', count: deploying.length }]
      : []),
    { id: 'inactive' as FilterTab, label: 'Inactive', count: inactive.length },
  ];

  // ─── Render ────────────────────────────────────────────────────────────────
  return (
    <SafeAreaView className="flex-1 bg-white dark:bg-neutral-950">
      {/* Header */}
      <View className="flex flex-row justify-between items-center px-4 min-h-[49px] border-b border-gray-200 dark:border-neutral-800">
        <Text className="text-base font-medium text-neutral-900 dark:text-white">
          Projects
        </Text>
        <Button
          variant="default"
          size="sm"
          onPress={() => router.push('/project/new' as any)}
        >
          <Plus size={16} color="#fff" strokeWidth={2} />
          <Text className="text-xs font-medium text-white">New Deployment</Text>
        </Button>
      </View>

      {/* Filters */}
      <ProjectFilters
        tabs={tabs}
        activeTab={activeTab}
        onTabChange={setActiveTab}
      />

      {/* Project List */}
      <ScrollView
        contentContainerStyle={{
          paddingHorizontal: 16,
          paddingVertical: 16,
          gap: 16,
          flexDirection: numColumns > 1 ? 'row' : 'column',
          flexWrap: numColumns > 1 ? 'wrap' : 'nowrap',
          alignItems: numColumns > 1 ? 'flex-start' : 'stretch',
        }}
        showsVerticalScrollIndicator={false}
      >
        {filtered.length === 0 ? (
          <ProjectEmptyState />
        ) : (
          filtered.map(project => (
            <View
              key={project.id}
              style={cardWidth !== undefined ? { width: cardWidth } : { width: '100%' }}
            >
              <ProjectCard project={project} />
            </View>
          ))
        )}
        <View className="h-5 w-full" />
      </ScrollView>
    </SafeAreaView>
  );
}
