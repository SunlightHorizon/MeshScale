// ─── StatCard ────────────────────────────────────────────────────────────
// Dashboard stat card with icon, value, trend badge, and footer text.
// Appears in the horizontal scroll row at the top of the dashboard.

import React from 'react';
import { View, Text } from 'react-native';
import { TrendingUp, TrendingDown } from 'lucide-react-native';
import { Card } from '@/components/ui/card';
import { cn } from '@/lib/tailwind-utils';

interface StatCardProps {
  description: string;
  Icon: React.ComponentType<{ size?: number; color?: string; strokeWidth?: number }>;
  value: string;
  valueSuffix?: string;
  badgeText: string;
  badgeTrending: 'up' | 'down';
  footerBold: string;
  footerMuted: string;
  className?: string;
}

export function StatCard({
  description,
  Icon,
  value,
  valueSuffix,
  badgeText,
  badgeTrending,
  footerBold,
  footerMuted,
  className,
}: StatCardProps) {
  const TrendIcon = badgeTrending === 'up' ? TrendingUp : TrendingDown;

  return (
    <Card className={cn('w-55 flex-shrink-0', className)}>
      {/* Header */}
      <View className="flex flex-col gap-2">
        <View className="flex flex-row justify-between items-start">
          <View className="flex flex-row items-center gap-1.5 flex-1">
            <Icon size={14} color="#71717a" strokeWidth={2} />
            <Text className="text-sm text-neutral-600 dark:text-neutral-400">
              {description}
            </Text>
          </View>
          <View className="flex flex-row items-center gap-1 px-2 py-0.5 rounded-full border border-gray-200 dark:border-neutral-800">
            <TrendIcon size={12} color="#171717" strokeWidth={2} className="dark:text-white" />
            <Text className="text-xs font-medium text-neutral-900 dark:text-white">
              {badgeText}
            </Text>
          </View>
        </View>
        <View className="flex flex-row items-end">
          <Text className="text-3xl font-semibold tabular-nums text-neutral-900 dark:text-white">
            {value}
          </Text>
          {valueSuffix ? (
            <Text className="text-2xl font-normal text-neutral-600 dark:text-neutral-400 mb-0.25">
              {valueSuffix}
            </Text>
          ) : null}
        </View>
      </View>

      {/* Footer */}
      <View className="flex flex-col gap-1.5 mt-1">
        <Text className="text-sm font-semibold text-neutral-900 dark:text-white" numberOfLines={1}>
          {footerBold}
        </Text>
        <Text className="text-sm text-neutral-600 dark:text-neutral-400">
          {footerMuted}
        </Text>
      </View>
    </Card>
  );
}
