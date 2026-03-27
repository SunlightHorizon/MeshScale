// ─── ProjectFilters ─────────────────────────────────────────────────────
// Filter tabs (All | Running | Deploying | Inactive) with counts.

import React from 'react';
import { View, Text, ScrollView, TouchableOpacity } from 'react-native';
import { cn } from '@/lib/tailwind-utils';

export type FilterTab = 'all' | 'running' | 'deploying' | 'inactive';

interface FilterItem {
  id: FilterTab;
  label: string;
  count: number;
}

interface ProjectFiltersProps {
  tabs: FilterItem[];
  activeTab: FilterTab;
  onTabChange: (tab: FilterTab) => void;
}

export function ProjectFilters({ tabs, activeTab, onTabChange }: ProjectFiltersProps) {
  return (
    <View className="border-b border-gray-200 dark:border-neutral-800">
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={{ paddingHorizontal: 16, paddingVertical: 8 }}
      >
        {tabs.map(tab => (
          <TouchableOpacity
            key={tab.id}
            className={cn(
              'py-1 px-2 mr-0.5',
              activeTab === tab.id && 'border-b-2 border-indigo-600'
            )}
            onPress={() => onTabChange(tab.id)}
          >
            <Text
              className={cn(
                'text-sm font-medium',
                activeTab === tab.id
                  ? 'text-indigo-600 dark:text-indigo-400'
                  : 'text-neutral-600 dark:text-neutral-400'
              )}
            >
              {tab.label} ({tab.count})
            </Text>
          </TouchableOpacity>
        ))}
      </ScrollView>
    </View>
  );
}
