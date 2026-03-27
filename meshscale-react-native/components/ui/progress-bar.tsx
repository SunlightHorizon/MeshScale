// ─── ProgressBar ─────────────────────────────────────────────────────────────
// Reusable resource usage bar. Used in project cards and project detail.

import React from 'react';
import { View, Text } from 'react-native';
import { cn } from '@/lib/tailwind-utils';

interface ProgressBarProps {
  label: string;
  value: number; // 0-100
  className?: string;
  colorThresholds?: {
    high: string;
    medium: string;
    low: string;
  };
}

const DEFAULT_THRESHOLDS = {
  high: 'bg-red-500', // red — > 80%
  medium: 'bg-yellow-500', // yellow — > 60%
  low: 'bg-green-500', // green — <= 60%
};

export function ProgressBar({
  label,
  value,
  className,
  colorThresholds,
}: ProgressBarProps) {
  const getBarColor = () => {
    if (value > 80) {
      return colorThresholds?.high || DEFAULT_THRESHOLDS.high;
    }
    if (value > 60) {
      return colorThresholds?.medium || DEFAULT_THRESHOLDS.medium;
    }
    return colorThresholds?.low || DEFAULT_THRESHOLDS.low;
  };

  const getTextColor = () => {
    if (value > 80) return 'text-red-600 dark:text-red-400';
    if (value > 60) return 'text-yellow-600 dark:text-yellow-400';
    return 'text-green-600 dark:text-green-400';
  };

  return (
    <View className={cn('flex flex-col gap-1', className)}>
      <View className="flex flex-row items-center justify-between">
        <Text className="text-xs text-neutral-600 dark:text-neutral-400">{label}</Text>
        <Text className={cn('text-xs font-medium tabular-nums', getTextColor())}>
          {value}%
        </Text>
      </View>
      <View className="h-1.5 w-full rounded-full bg-gray-200 dark:bg-neutral-700 overflow-hidden">
        <View
          className={cn('h-full rounded-full', getBarColor())}
          style={{ width: `${value}%` }}
        />
      </View>
    </View>
  );
}
