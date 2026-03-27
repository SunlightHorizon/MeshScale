// ─── Dashboard Screen ────────────────────────────────────────────────────────
// Thin orchestrator that composes feature components.

import React, { useState } from 'react';
import { View, Text, ScrollView, TouchableOpacity } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Server, CheckCircle2, Zap, Activity } from 'lucide-react-native';
import { cn } from '@/lib/tailwind-utils';

import { useStore } from '@/lib/store';
import { Card, CardContent } from '@/components/ui/card';
import { StatCard } from '@/features/dashboard/stat-card';
import { AreaChart } from '@/features/dashboard/area-chart';
import { ServicesTable } from '@/features/dashboard/services-table';
import { CostBreakdown } from '@/features/dashboard/cost-breakdown';

export default function DashboardScreen() {
  const { projects, deployments } = useStore();
  const [timeRange, setTimeRange] = useState<'90d' | '30d' | '7d'>('7d');

  // ─── Derived data ──────────────────────────────────────────────────────────
  const activeCount = projects.filter(p => p.status === 'running').length;
  const totalCount = projects.length;
  const successDeploys = deployments.filter(d => d.status === 'success').length;
  const failedDeploys = deployments.filter(d => d.status === 'failed').length;
  const totalDeploys = deployments.length;

  const runningProjects = projects.filter(p => p.status === 'running' && p.uptime !== '—');
  const avgUptime =
    runningProjects.length > 0
      ? (
          runningProjects.reduce((sum, p) => {
            const val = parseFloat(p.uptime.replace('%', ''));
            return sum + (isNaN(val) ? 0 : val);
          }, 0) / runningProjects.length
        ).toFixed(2) + '%'
      : '—';

  // ─── Render ────────────────────────────────────────────────────────────────
  return (
    <SafeAreaView className="flex-1 bg-white dark:bg-neutral-950">
      {/* Header */}
      <View className="px-4 min-h-[49px] justify-center border-b border-gray-200 dark:border-neutral-800">
        <Text className="text-base font-medium text-neutral-900 dark:text-white">
          Analytics
        </Text>
      </View>

      <ScrollView
        className="flex-1"
        contentContainerStyle={{ paddingHorizontal: 16, paddingVertical: 24, gap: 24 }}
        showsVerticalScrollIndicator={false}
      >
        {/* Stat Cards */}
        <ScrollView horizontal showsHorizontalScrollIndicator={false}>
          <View className="flex flex-row gap-4 pr-4">
            <StatCard
              description="Active Services"
              Icon={Server}
              value={String(activeCount)}
              valueSuffix={`/${totalCount}`}
              badgeText={`${totalCount} total`}
              badgeTrending="up"
              footerBold={`${activeCount} running now`}
              footerMuted="Websites, APIs, and game servers"
            />
            <StatCard
              description="Deployments"
              Icon={CheckCircle2}
              value={String(totalDeploys)}
              badgeText={`${successDeploys} succeeded`}
              badgeTrending={failedDeploys > 0 ? 'down' : 'up'}
              footerBold={`${failedDeploys} failed`}
              footerMuted={`${successDeploys} successful deployments`}
            />
            <StatCard
              description="Avg. Uptime"
              Icon={Zap}
              value={avgUptime}
              badgeText="running"
              badgeTrending="up"
              footerBold={`Across ${runningProjects.length} running service${runningProjects.length !== 1 ? 's' : ''}`}
              footerMuted="Based on reported uptime"
            />
            <StatCard
              description="Control Plane"
              Icon={Activity}
              value="99.97%"
              badgeText="+0.12%"
              badgeTrending="up"
              footerBold="Up 0.12% vs last month"
              footerMuted="Compared to 99.85% last month"
            />
          </View>
        </ScrollView>

        {/* Chart Card */}
        <Card>
          <View className="flex flex-row justify-between items-start gap-2 px-6">
            <View className="flex-1 gap-1">
              <Text className="text-base font-semibold text-neutral-900 dark:text-white leading-5">
                Total Visitors
              </Text>
              <Text className="text-sm text-neutral-600 dark:text-neutral-400">
                Last 3 months
              </Text>
            </View>
            <View className="flex flex-row">
              {(['90d', '30d', '7d'] as const).map(range => (
                <TouchableOpacity
                  key={range}
                  onPress={() => setTimeRange(range)}
                  className={cn(
                    'px-2.5 py-1.5 border border-gray-200 dark:border-neutral-800',
                    timeRange === range && 'bg-gray-100 dark:bg-neutral-800'
                  )}
                >
                  <Text
                    className={cn(
                      'text-xs font-medium',
                      timeRange === range
                        ? 'text-neutral-900 dark:text-white'
                        : 'text-neutral-600 dark:text-neutral-400'
                    )}
                  >
                    {range === '90d' ? '3mo' : range === '30d' ? '30d' : '7d'}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>
          </View>
          <CardContent>
            <AreaChart />
          </CardContent>
        </Card>

        {/* Services Table */}
        <ServicesTable projects={projects} />

        {/* Cost Breakdown */}
        <CostBreakdown />

        <View className="h-5" />
      </ScrollView>
    </SafeAreaView>
  );
}
