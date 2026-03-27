// ─── Project Detail Screen ───────────────────────────────────────────────────
// Thin orchestrator composing header, navigation, and section components.

import React, { useState } from 'react';
import { View, Text, ScrollView, TouchableOpacity } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useLocalSearchParams, router } from 'expo-router';
import { AlertCircle } from 'lucide-react-native';
import { cn } from '@/lib/tailwind-utils';

import { useStore } from '@/lib/store';
import { useLargeScreen } from '@/hooks/use-large-screen';
import { AppSidebar } from '@/components/layout/app-sidebar';

import { ProjectHeader } from '@/features/project-detail/project-header';
import {
  ProjectSidebarNav,
  ProjectTabBarNav,
  Section,
} from '@/features/project-detail/project-nav';
import { OverviewSection } from '@/features/project-detail/overview-section';
import { DeploymentsSection } from '@/features/project-detail/deployments-section';
import { LogsSection } from '@/features/project-detail/logs-section';
import { EnvironmentSection } from '@/features/project-detail/environment-section';
import { ProjectSettingsSection } from '@/features/project-detail/settings-section';

export default function ProjectDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { projects, deployments } = useStore();
  const [activeSection, setActiveSection] = useState<Section>('overview');
  const isLargeScreen = useLargeScreen();

  const project = projects.find(p => p.id === id);
  const projectDeployments = deployments.filter(d => d.projectId === id);

  // ─── Not Found ─────────────────────────────────────────────────────────────
  if (!project) {
    return (
      <SafeAreaView className="flex-1 bg-white dark:bg-neutral-950">
        <View className="flex-1 items-center justify-center gap-3">
          <AlertCircle size={48} color="#71717a" strokeWidth={1.5} />
          <Text className="text-lg font-semibold text-neutral-900 dark:text-white">
            Project not found
          </Text>
          <TouchableOpacity onPress={() => router.back()}>
            <Text className="text-base text-indigo-600 dark:text-indigo-400">
              Go back
            </Text>
          </TouchableOpacity>
        </View>
      </SafeAreaView>
    );
  }

  // ─── Section Content ───────────────────────────────────────────────────────
  const sectionContent = (
    <ScrollView
      className="flex-1"
      contentContainerStyle={{ paddingHorizontal: 24, paddingVertical: 24, gap: 24 }}
      showsVerticalScrollIndicator={false}
    >
      {activeSection === 'overview' && (
        <OverviewSection project={project} deployments={projectDeployments} />
      )}
      {activeSection === 'deployments' && (
        <DeploymentsSection deployments={projectDeployments} />
      )}
      {activeSection === 'logs' && (
        <LogsSection project={project} />
      )}
      {activeSection === 'environment' && (
        <EnvironmentSection />
      )}
      {activeSection === 'settings-section' && (
        <ProjectSettingsSection project={project} />
      )}
      <View className="h-5" />
    </ScrollView>
  );

  // ─── Render ────────────────────────────────────────────────────────────────
  return (
    <View className="flex-1 flex-row bg-white dark:bg-neutral-950">
      {isLargeScreen && <AppSidebar />}

      <SafeAreaView className="flex-1 bg-white dark:bg-neutral-950">
        <ProjectHeader project={project} />

        <View className="flex-1 flex-row">
          {isLargeScreen ? (
            <>
              <ProjectSidebarNav
                project={project}
                activeSection={activeSection}
                onSectionChange={setActiveSection}
              />
              {sectionContent}
            </>
          ) : (
            <>
              <View className="flex-1 flex-col">
                <ProjectTabBarNav
                  activeSection={activeSection}
                  onSectionChange={setActiveSection}
                />
                {sectionContent}
              </View>
            </>
          )}
        </View>
      </SafeAreaView>
    </View>
  );
}
