// ─── ProjectEmptyState ──────────────────────────────────────────────────
// Empty state shown when no projects match the current filter.

import React from 'react';
import { View, Text, TouchableOpacity } from 'react-native';
import { FolderOpen, Plus } from 'lucide-react-native';
import { router } from 'expo-router';

interface ProjectEmptyStateProps {
  className?: string;
}

export function ProjectEmptyState({ className }: ProjectEmptyStateProps) {
  return (
    <View className="flex-1 items-center justify-center pt-20 gap-2">
      <FolderOpen size={48} color="#71717a" strokeWidth={1.5} />
      <Text className="text-lg font-semibold text-neutral-900 dark:text-white">
        No services here
      </Text>
      <Text className="text-sm text-center text-neutral-600 dark:text-neutral-400">
        Deploy your first project to get started
      </Text>
      <TouchableOpacity
        className="flex flex-row items-center gap-1 px-3 py-1.75 rounded-md bg-indigo-600 dark:bg-indigo-500 mt-4"
        onPress={() => router.push('/project/new' as any)}
      >
        <Plus size={16} color="#fff" strokeWidth={2} />
        <Text className="text-white text-xs font-medium">
          New Deployment
        </Text>
      </TouchableOpacity>
    </View>
  );
}
