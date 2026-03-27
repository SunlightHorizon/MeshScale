// ─── ProjectHeader ──────────────────────────────────────────────────────────
// Breadcrumb header with back button, type icon, project name, status, and actions.

import React from 'react';
import { View, Text, TouchableOpacity } from 'react-native';
import { ChevronLeft, ExternalLink, Rocket } from 'lucide-react-native';
import { router } from 'expo-router';
import { cn } from '@/lib/tailwind-utils';

import { StatusBadge } from '@/components/shared/status-badge';
import { TypeIcon } from '@/components/shared/type-icon';
import { Button } from '@/components/ui/button';
import type { Project } from '@/lib/types';

interface ProjectHeaderProps {
  project: Project;
  className?: string;
}

export function ProjectHeader({ project, className }: ProjectHeaderProps) {
  return (
    <View
      className={cn(
        'flex flex-row items-center gap-1.5',
        'px-4 min-h-[49px]',
        'border-b border-gray-200 dark:border-neutral-800',
        className
      )}
    >
      {/* Back button */}
      <TouchableOpacity
        className="flex flex-row items-center gap-0.5"
        onPress={() => router.back()}
      >
        <ChevronLeft size={20} color="#71717a" strokeWidth={2} />
        <Text className="text-sm text-neutral-600 dark:text-neutral-400">
          Projects
        </Text>
      </TouchableOpacity>

      {/* Separator */}
      <Text className="text-sm text-neutral-600 dark:text-neutral-400 mx-0.5">
        /
      </Text>

      {/* Type icon */}
      <TypeIcon type={project.type} size="sm" />

      {/* Project name */}
      <Text
        className="flex-1 min-w-0 text-sm font-medium text-neutral-900 dark:text-white"
        numberOfLines={1}
      >
        {project.name}
      </Text>

      {/* Status badge */}
      <StatusBadge status={project.status} />

      {/* Actions */}
      <View className="flex flex-row items-center gap-2">
        {project.url ? (
          <Button variant="outline" size="sm">
            <ExternalLink size={14} color="#71717a" strokeWidth={2} />
            <Text className="text-xs text-neutral-600 dark:text-neutral-400">
              Visit
            </Text>
          </Button>
        ) : null}
        <Button variant="default" size="sm">
          <Rocket size={14} color="#fff" strokeWidth={2} />
          <Text className="text-xs font-semibold text-white">Deploy</Text>
        </Button>
      </View>
    </View>
  );
}
