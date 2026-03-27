// ─── ProjectCard ────────────────────────────────────────────────────────
// Card displaying a single project with type, status, stats, and resource bars.

import React from 'react';
import { View, Text, TouchableOpacity } from 'react-native';
import { MapPin, Zap, MoreVertical } from 'lucide-react-native';
import { router } from 'expo-router';
import { cn } from '@/lib/tailwind-utils';

import { StatusBadge, TypeBadge } from '@/components/shared/status-badge';
import { TypeIcon } from '@/components/shared/type-icon';
import { ProgressBar } from '@/components/ui/progress-bar';
import { Button } from '@/components/ui/button';
import { TYPE_LABELS } from '@/constants/project';
import type { Project } from '@/lib/types';

interface ProjectCardProps {
  project: Project;
}

export function ProjectCard({ project }: ProjectCardProps) {
  const isRunning = project.status === 'running';

  return (
    <TouchableOpacity
      className={cn(
        'rounded-lg border border-gray-200 dark:border-neutral-800',
        'bg-white dark:bg-neutral-900',
        'shadow-sm'
      )}
      onPress={() => router.push(`/project/${project.id}` as any)}
      activeOpacity={0.8}
    >
      {/* Header */}
      <View className="px-6 pt-6 pb-3">
        <View className="flex flex-row justify-between items-start">
          <View className="flex flex-row items-start gap-3 flex-1">
            <View className="mt-0.5">
              <TypeIcon type={project.type} />
            </View>
            <View className="flex-1 min-w-0">
              <Text className="text-base font-semibold text-neutral-900 dark:text-white leading-6" numberOfLines={1}>
                {project.name}
              </Text>
              <Text className="text-xs text-neutral-600 dark:text-neutral-400 leading-4 mt-0.5" numberOfLines={2}>
                {project.description}
              </Text>
            </View>
          </View>
          <TouchableOpacity className="w-7 h-7 flex items-center justify-center flex-shrink-0 ml-2" hitSlop={8}>
            <MoreVertical size={14} color="#71717a" strokeWidth={2} />
          </TouchableOpacity>
        </View>
      </View>

      {/* Content */}
      <View className="px-6 pb-6 gap-4">
        {/* Badges */}
        <View className="flex flex-row gap-2 flex-wrap">
          <StatusBadge status={project.status} />
          <TypeBadge type={project.type} label={TYPE_LABELS[project.type] ?? project.type} />
        </View>

        {/* Stats */}
        <View className="flex flex-row gap-2">
          <View className="flex flex-row items-center gap-1.5 flex-1">
            <MapPin size={12} color="#71717a" strokeWidth={2} />
            <Text className="text-xs text-neutral-600 dark:text-neutral-400" numberOfLines={1}>
              {project.region}
            </Text>
          </View>
          <View className="flex flex-row items-center gap-1.5">
            <Zap size={12} color="#71717a" strokeWidth={2} />
            <Text className="text-xs text-neutral-600 dark:text-neutral-400">
              {project.uptime} uptime
            </Text>
          </View>
        </View>

        {/* Resource bars (running only) */}
        {isRunning && (
          <View>
            <ProgressBar label="CPU" value={project.cpu} />
            <View className="h-2" />
            <ProgressBar
              label="Memory"
              value={project.memory}
              colorThresholds={{ high: 'bg-red-500', medium: 'bg-amber-400', low: 'bg-blue-500' }}
            />
          </View>
        )}

        {/* Footer */}
        <View className="flex flex-row justify-between items-center pt-3 border-t border-gray-200 dark:border-neutral-800">
          <Text className="text-xs text-neutral-600 dark:text-neutral-400">
            {project.instances > 0
              ? `${project.instances} instance${project.instances !== 1 ? 's' : ''}`
              : 'No instances'}
          </Text>
          <Text className="text-xs text-neutral-600 dark:text-neutral-400">
            Deployed {project.lastDeployed}
          </Text>
        </View>

        {/* View button */}
        <Button
          variant="outline"
          size="sm"
          onPress={() => router.push(`/project/${project.id}` as any)}
        >
          View Project
        </Button>
      </View>
    </TouchableOpacity>
  );
}
