// ─── TypeIcon ────────────────────────────────────────────────────────────────
// Renders a project type icon inside a colored rounded square.
// Used in project cards, project detail header, and breadcrumbs.

import React from 'react';
import { View } from 'react-native';
import { Code2 } from 'lucide-react-native';
import { TypeColors } from '@/constants/theme';
import { TYPE_ICONS } from '@/constants/project';
import { cn } from '@/lib/tailwind-utils';
import type { ProjectType } from '@/lib/types';

interface TypeIconProps {
  type: ProjectType;
  size?: 'sm' | 'md' | 'lg'; // small: 24px, medium: 36px, large: 48px
  className?: string;
}

const sizeMap = {
  sm: { container: 'w-6 h-6', icon: 16, borderRadius: 'rounded-md' },
  md: { container: 'w-9 h-9', icon: 20, borderRadius: 'rounded-lg' },
  lg: { container: 'w-12 h-12', icon: 24, borderRadius: 'rounded-xl' },
};

export function TypeIcon({ type, size = 'md', className }: TypeIconProps) {
  const typeColor = TypeColors[type] ?? { bg: '#f3f4f6', text: '#6b7280' };
  const Icon = TYPE_ICONS[type] ?? Code2;
  const { container, icon, borderRadius } = sizeMap[size];

  // Map hex colors to Tailwind classes
  const bgClass = {
    '#dbeafe': 'bg-blue-100 dark:bg-blue-950',
    '#f3e8ff': 'bg-purple-100 dark:bg-purple-950',
    '#dcfce7': 'bg-green-100 dark:bg-green-950',
    '#fff7ed': 'bg-orange-100 dark:bg-orange-950',
    '#fef9c3': 'bg-yellow-100 dark:bg-yellow-950',
    '#f3f4f6': 'bg-gray-100 dark:bg-gray-800',
  }[typeColor.bg] || 'bg-gray-100 dark:bg-gray-800';

  const textClass = {
    '#1d4ed8': 'text-blue-700 dark:text-blue-400',
    '#7c3aed': 'text-purple-700 dark:text-purple-400',
    '#15803d': 'text-green-700 dark:text-green-400',
    '#c2410c': 'text-orange-700 dark:text-orange-400',
    '#a16207': 'text-yellow-700 dark:text-yellow-400',
    '#6b7280': 'text-gray-700 dark:text-gray-400',
  }[typeColor.text] || 'text-gray-700 dark:text-gray-400';

  return (
    <View
      className={cn(
        'flex items-center justify-center flex-shrink-0',
        container,
        borderRadius,
        bgClass,
        className
      )}
    >
      <Icon size={icon} strokeWidth={2} color={typeColor.text} />
    </View>
  );
}
