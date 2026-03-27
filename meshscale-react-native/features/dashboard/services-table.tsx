// ─── ServicesTable ───────────────────────────────────────────────────────────
// Data table showing services with type, status, and uptime.
// Includes tab pills, column headers, paginated rows, and navigation.

import React, { useState } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
} from 'react-native';
import {
  Plus,
  Columns3,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  ChevronsLeft,
  ChevronsRight,
  GripVertical,
  MoreVertical,
} from 'lucide-react-native';
import { router } from 'expo-router';
import { cn } from '@/lib/tailwind-utils';

import { StatusBadge } from '@/components/shared/status-badge';
import type { Project } from '@/lib/types';

interface ServicesTableProps {
  projects: Project[];
}

export function ServicesTable({ projects }: ServicesTableProps) {
  const [currentPage, setCurrentPage] = useState(0);
  const pageSize = 10;
  const totalPages = Math.max(1, Math.ceil(projects.length / pageSize));
  const currentData = projects.slice(
    currentPage * pageSize,
    (currentPage + 1) * pageSize,
  );

  return (
    <View className="gap-4">
      {/* Header row: tabs + action buttons */}
      <View className="flex flex-row items-center gap-2">
        <ScrollView horizontal showsHorizontalScrollIndicator={false} className="flex-1">
          <View className="flex flex-row gap-0.5">
            {[
              { label: 'Services', badge: null },
              { label: 'Deployments', badge: '3' },
              { label: 'Alerts', badge: '2' },
              { label: 'Costs', badge: null },
            ].map((tab, i) => (
              <View
                key={tab.label}
                className={cn(
                  'flex flex-row items-center gap-1 px-3 py-1.5 rounded-md border',
                  i === 0
                    ? 'bg-white dark:bg-neutral-800 border-gray-200 dark:border-neutral-700 shadow-sm'
                    : 'border-transparent'
                )}
              >
                <Text className={cn(
                  'text-sm font-medium',
                  i === 0 ? 'text-neutral-900 dark:text-white' : 'text-neutral-600 dark:text-neutral-400'
                )}>
                  {tab.label}
                </Text>
                {tab.badge ? (
                  <View className="min-w-5 h-5 rounded-full bg-gray-100 dark:bg-neutral-700 flex items-center justify-center px-1">
                    <Text className="text-xs font-medium text-neutral-600 dark:text-neutral-400">
                      {tab.badge}
                    </Text>
                  </View>
                ) : null}
              </View>
            ))}
          </View>
        </ScrollView>

        <View className="flex flex-row gap-2">
          <TouchableOpacity className="flex flex-row items-center gap-1 px-3 py-1.75 rounded-md border border-gray-200 dark:border-neutral-800">
            <Columns3 size={14} color="#171717" strokeWidth={2} className="dark:text-white" />
            <Text className="text-sm text-neutral-900 dark:text-white">Columns</Text>
            <ChevronDown size={14} color="#171717" strokeWidth={2} className="dark:text-white" />
          </TouchableOpacity>
          <TouchableOpacity className="flex flex-row items-center gap-1 px-3 py-1.75 rounded-md border border-gray-200 dark:border-neutral-800">
            <Plus size={14} color="#171717" strokeWidth={2} className="dark:text-white" />
            <Text className="text-sm text-neutral-900 dark:text-white">Add Service</Text>
          </TouchableOpacity>
        </View>
      </View>

      {/* Table */}
      <View className="rounded-lg border border-gray-200 dark:border-neutral-800 overflow-hidden">
        {/* Header row */}
        <View
          className="flex flex-row items-center px-4 py-3 bg-gray-50 dark:bg-neutral-800 border-b border-gray-200 dark:border-neutral-700"
        >
          <View className="w-5 items-center">
            <GripVertical size={12} color="#71717a" strokeWidth={2} />
          </View>
          <Text className="text-xs font-medium text-neutral-600 dark:text-neutral-400 flex-1 ml-2" style={{ flex: 2 }}>
            Service
          </Text>
          <Text className="text-xs font-medium text-neutral-600 dark:text-neutral-400" style={{ flex: 1.2 }}>
            Type
          </Text>
          <Text className="text-xs font-medium text-neutral-600 dark:text-neutral-400" style={{ flex: 1.5 }}>
            Status
          </Text>
          <Text className="text-xs font-medium text-neutral-600 dark:text-neutral-400 text-right" style={{ flex: 1 }}>
            Uptime
          </Text>
          <View className="w-6" />
        </View>

        {/* Data rows */}
        {currentData.slice(0, 6).map((project, index) => (
          <TouchableOpacity
            key={project.id}
            className={cn(
              'flex flex-row items-center px-4 py-3 gap-1',
              index > 0 && 'border-t border-gray-200 dark:border-neutral-800'
            )}
            onPress={() => router.push(`/project/${project.id}` as any)}
          >
            <View className="w-5 items-center">
              <GripVertical size={12} color="#71717a" strokeWidth={2} />
            </View>
            <Text
              className="text-sm text-indigo-600 dark:text-indigo-400 flex-1 ml-2"
              numberOfLines={1}
              style={{ flex: 2 }}
            >
              {project.name}
            </Text>
            <View style={{ flex: 1.2 }}>
              <View className="self-start px-1.5 py-0.5 rounded-full border border-gray-200 dark:border-neutral-800">
                <Text className="text-xs font-medium text-neutral-600 dark:text-neutral-400" numberOfLines={1}>
                  {project.type
                    .split('-')
                    .map((w: string) => w[0].toUpperCase() + w.slice(1))
                    .join(' ')}
                </Text>
              </View>
            </View>
            <View style={{ flex: 1.5 }}>
              <StatusBadge status={project.status} />
            </View>
            <Text
              className="text-sm text-neutral-900 dark:text-white text-right tabular-nums"
              style={{ flex: 1 }}
            >
              {project.uptime}
            </Text>
            <TouchableOpacity className="w-6 items-center">
              <MoreVertical size={14} color="#71717a" strokeWidth={2} />
            </TouchableOpacity>
          </TouchableOpacity>
        ))}
      </View>

      {/* Pagination */}
      <View className="flex flex-row justify-between items-center px-1">
        <Text className="text-sm text-neutral-600 dark:text-neutral-400">
          Page {currentPage + 1} of {totalPages}
        </Text>
        <View className="flex flex-row gap-2">
          {[
            { icon: ChevronsLeft, onPress: () => setCurrentPage(0), disabled: currentPage === 0 },
            {
              icon: ChevronLeft,
              onPress: () => setCurrentPage(p => Math.max(0, p - 1)),
              disabled: currentPage === 0,
            },
            {
              icon: ChevronRight,
              onPress: () => setCurrentPage(p => Math.min(totalPages - 1, p + 1)),
              disabled: currentPage >= totalPages - 1,
            },
            {
              icon: ChevronsRight,
              onPress: () => setCurrentPage(totalPages - 1),
              disabled: currentPage >= totalPages - 1,
            },
          ].map((btn, i) => (
            <TouchableOpacity
              key={i}
              className={cn(
                'w-8 h-8 rounded-md border border-gray-200 dark:border-neutral-800 flex items-center justify-center',
                btn.disabled && 'opacity-40'
              )}
              onPress={btn.onPress}
              disabled={btn.disabled}
            >
              <btn.icon size={14} color="#171717" strokeWidth={2} className="dark:text-white" />
            </TouchableOpacity>
          ))}
        </View>
      </View>
    </View>
  );
}
