// ─── DeploymentsSection ─────────────────────────────────────────────────────
// Full deployment history with status icons, commit info, and timing.

import React from 'react';
import { View, Text } from 'react-native';
import {
  Rocket,
  CheckCircle2,
  XCircle,
  Loader2,
  GitCommit,
  GitBranch,
  User,
} from 'lucide-react-native';

import { Card } from '@/components/ui/card';
import { StatusBadge } from '@/components/shared/status-badge';
import type { Deployment } from '@/lib/types';
import { cn } from '@/lib/tailwind-utils';

const DEPLOY_STATUS_CONFIG: Record<
  string,
  { Icon: React.ComponentType<{ size?: number; color?: string; strokeWidth?: number }>; color: string }
> = {
  success: { Icon: CheckCircle2, color: '#16a34a' },
  failed: { Icon: XCircle, color: '#dc2626' },
  'in-progress': { Icon: Loader2, color: '#ca8a04' },
};

interface DeploymentsSectionProps {
  deployments: Deployment[];
}

export function DeploymentsSection({ deployments }: DeploymentsSectionProps) {
  if (deployments.length === 0) {
    return (
      <View className="items-center pt-15 gap-2">
        <Rocket size={40} color="#999" strokeWidth={1.5} />
        <Text className="text-lg font-semibold text-neutral-900 dark:text-white">No deployments yet</Text>
        <Text className="text-sm text-neutral-500 dark:text-neutral-400">
          Trigger a deployment to see history here
        </Text>
      </View>
    );
  }

  return (
    <View className="gap-6">
      <View className="gap-1">
        <Text className="text-lg font-semibold text-neutral-900 dark:text-white">Deployments</Text>
        <Text className="text-sm text-neutral-500 dark:text-neutral-400">Full deployment history</Text>
      </View>

      <Card>
        {deployments.map((dep, i) => {
          const cfg = DEPLOY_STATUS_CONFIG[dep.status] ?? DEPLOY_STATUS_CONFIG.success;
          return (
            <View
              key={dep.id}
              className={cn(
                'flex-row items-start gap-4 px-6 py-4',
                i > 0 && 'border-t border-neutral-200 dark:border-neutral-700'
              )}
            >
              <cfg.Icon size={20} color={cfg.color} strokeWidth={2} />
              <View className="flex-1">
                <Text className="text-sm font-medium text-neutral-900 dark:text-white" numberOfLines={1}>
                  {dep.message}
                </Text>
                <View className="flex-row gap-3 flex-wrap mt-1">
                  <View className="flex-row items-center gap-1 border border-neutral-200 dark:border-neutral-700 rounded-full px-1.5 py-0.5">
                    <GitCommit size={12} color="#999" strokeWidth={2} />
                    <Text className="text-xs text-neutral-500 dark:text-neutral-400 font-mono">{dep.commit}</Text>
                  </View>
                  <View className="flex-row items-center gap-1 border border-neutral-200 dark:border-neutral-700 rounded-full px-1.5 py-0.5">
                    <GitBranch size={12} color="#999" strokeWidth={2} />
                    <Text className="text-xs text-neutral-500 dark:text-neutral-400 font-mono">{dep.branch}</Text>
                  </View>
                  <View className="flex-row items-center gap-1">
                    <User size={12} color="#999" strokeWidth={2} />
                    <Text className="text-xs text-neutral-500 dark:text-neutral-400">
                      {dep.deployedBy}
                    </Text>
                  </View>
                </View>
              </View>
              <View className="items-end gap-1">
                <StatusBadge status={dep.status} />
                <Text className="text-xs text-neutral-500 dark:text-neutral-400">{dep.createdAt}</Text>
                {dep.duration !== '-' && (
                  <Text className="text-xs text-neutral-500 dark:text-neutral-400">{dep.duration}</Text>
                )}
              </View>
            </View>
          );
        })}
      </Card>
    </View>
  );
}

// ─── Styles ──────────────────────────────────────────────────────────────────
// All styling is now handled via Tailwind CSS classes
