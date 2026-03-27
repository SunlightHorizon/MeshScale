// ─── CostBreakdown ──────────────────────────────────────────────────────
// Monthly cost breakdown card with total and per-category rows.

import React from 'react';
import { View, Text } from 'react-native';
import { TrendingUp, TrendingDown, DollarSign } from 'lucide-react-native';
import { Card, CardHeader, CardContent } from '@/components/ui/card';
import { cn } from '@/lib/tailwind-utils';

// ─── CostRow ─────────────────────────────────────────────────────────────────

interface CostRowProps {
  label: string;
  amount: string;
  trend: string;
  up: boolean;
}

function CostRow({ label, amount, trend, up }: CostRowProps) {
  const TrendIcon = up ? TrendingUp : TrendingDown;
  const trendColor = up ? '#16a34a' : '#dc2626';

  return (
    <View className="flex flex-row justify-between items-center p-4 rounded-lg border border-gray-200 dark:border-neutral-800">
      <View>
        <Text className="text-sm font-medium text-neutral-900 dark:text-white">
          {label}
        </Text>
        <Text className="text-sm text-neutral-600 dark:text-neutral-400">
          {amount}
        </Text>
      </View>
      <View className="flex flex-row items-center gap-1 px-2 py-0.5 rounded-full border border-gray-200 dark:border-neutral-800">
        <TrendIcon size={12} color={trendColor} strokeWidth={2} />
        <Text style={{ color: trendColor }} className="text-xs font-medium">
          {trend}
        </Text>
      </View>
    </View>
  );
}

// ─── CostBreakdown ───────────────────────────────────────────────────────────

interface CostBreakdownProps {
  className?: string;
}

export function CostBreakdown({ className }: CostBreakdownProps) {
  return (
    <Card className={className}>
      <CardHeader
        title="Cost Breakdown"
        subtitle="Monthly expenses by category"
      />
      <CardContent>
        {/* Total row */}
        <View className="flex flex-row justify-between items-center p-4 rounded-lg border border-gray-200 dark:border-neutral-800">
          <View className="flex flex-row items-center gap-2">
            <View className="w-10 h-10 rounded-full bg-indigo-600 bg-opacity-10 dark:bg-indigo-500 dark:bg-opacity-10 flex items-center justify-center">
              <DollarSign size={20} color="#4f46e5" strokeWidth={2} className="dark:text-indigo-400" />
            </View>
            <View>
              <Text className="text-sm text-neutral-600 dark:text-neutral-400">
                Total Cost
              </Text>
              <Text className="text-2xl font-semibold text-neutral-900 dark:text-white">
                $66,950
              </Text>
            </View>
          </View>
        </View>

        {/* Category rows */}
        <View className="gap-3 mt-3">
          <CostRow label="Infrastructure" amount="$12,450" trend="8.2%" up />
          <CostRow label="Personnel" amount="$45,600" trend="2.1%" up={false} />
          <CostRow label="Software" amount="$8,900" trend="15.3%" up />
        </View>
      </CardContent>
    </Card>
  );
}
