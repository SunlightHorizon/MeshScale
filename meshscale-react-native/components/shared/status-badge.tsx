import React from 'react';
import { View, Text } from 'react-native';
import { StatusColors } from '@/constants/theme';
import { cn } from '@/lib/tailwind-utils';

type StatusKey = keyof typeof StatusColors;

interface StatusBadgeProps {
  status: string;
  className?: string;
}

/**
 * Status badge with colored background and indicator dot
 * Matches web Badge variant="secondary" styling
 * Usage: <StatusBadge status="running" />
 */
export function StatusBadge({ status, className }: StatusBadgeProps) {
  const config = StatusColors[status as StatusKey] ?? StatusColors.stopped;
  const label =
    status === 'in-progress'
      ? 'In Progress'
      : status.charAt(0).toUpperCase() + status.slice(1);

  // Map hex colors to Tailwind classes
  const bgClass = {
    '#dcfce7': 'bg-green-100 dark:bg-green-950',
    '#f3f4f6': 'bg-gray-100 dark:bg-gray-800',
    '#fef9c3': 'bg-yellow-100 dark:bg-yellow-950',
    '#fee2e2': 'bg-red-100 dark:bg-red-950',
  }[config.bg] || 'bg-gray-100 dark:bg-gray-800';

  const textClass = {
    '#15803d': 'text-green-700 dark:text-green-400',
    '#6b7280': 'text-gray-600 dark:text-gray-400',
    '#a16207': 'text-yellow-700 dark:text-yellow-400',
    '#dc2626': 'text-red-700 dark:text-red-400',
  }[config.text] || 'text-gray-700 dark:text-gray-300';

  const dotClass = {
    '#16a34a': 'bg-green-600 dark:bg-green-500',
    '#9ca3af': 'bg-gray-500 dark:bg-gray-400',
    '#ca8a04': 'bg-yellow-600 dark:bg-yellow-500',
    '#ef4444': 'bg-red-600 dark:bg-red-500',
  }[config.dot] || 'bg-gray-500 dark:bg-gray-400';

  return (
    <View
      className={cn(
        'flex flex-row items-center gap-1.5 px-2 py-0.5 rounded-full self-start',
        bgClass,
        className
      )}
    >
      <View className={cn('size-1.5 rounded-full', dotClass)} />
      <Text className={cn('text-xs font-medium', textClass)}>{label}</Text>
    </View>
  );
}

interface TypeBadgeProps {
  type: string;
  label: string;
  className?: string;
}

/**
 * Type badge with colored outline
 * Matches web Badge variant="outline" styling
 * Usage: <TypeBadge type="website" label="Website" />
 */
export function TypeBadge({ type, label, className }: TypeBadgeProps) {
  const colorMap: Record<string, { bg: string; border: string; text: string }> = {
    website: {
      bg: 'bg-blue-50 dark:bg-blue-950',
      border: 'border-blue-300 dark:border-blue-700',
      text: 'text-blue-700 dark:text-blue-400',
    },
    'game-server': {
      bg: 'bg-purple-50 dark:bg-purple-950',
      border: 'border-purple-300 dark:border-purple-700',
      text: 'text-purple-700 dark:text-purple-400',
    },
    api: {
      bg: 'bg-green-50 dark:bg-green-950',
      border: 'border-green-300 dark:border-green-700',
      text: 'text-green-700 dark:text-green-400',
    },
    worker: {
      bg: 'bg-orange-50 dark:bg-orange-950',
      border: 'border-orange-300 dark:border-orange-700',
      text: 'text-orange-700 dark:text-orange-400',
    },
    cron: {
      bg: 'bg-yellow-50 dark:bg-yellow-950',
      border: 'border-yellow-300 dark:border-yellow-700',
      text: 'text-yellow-700 dark:text-yellow-400',
    },
  };

  const colors = colorMap[type] || {
    bg: 'bg-gray-50 dark:bg-gray-900',
    border: 'border-gray-300 dark:border-gray-700',
    text: 'text-gray-700 dark:text-gray-400',
  };

  return (
    <View
      className={cn(
        'flex items-center justify-center px-2 py-0.5 rounded-full border self-start',
        colors.bg,
        colors.border,
        className
      )}
    >
      <Text className={cn('text-xs font-medium', colors.text)}>{label}</Text>
    </View>
  );
}
