// ─── OverviewSection ────────────────────────────────────────────────────────
// Project overview: stat cards, resource usage, recent deployments, service info.

import React from 'react';
import { View, Text } from 'react-native';
import {
  Settings,
  Activity,
  Cpu,
  Server,
  GitCommit,
  GitBranch,
  User,
  CheckCircle2,
  XCircle,
  Loader2,
} from 'lucide-react-native';

import { Card, CardHeader, CardContent } from '@/components/ui/card';
import { ProgressBar } from '@/components/ui/progress-bar';
import { TYPE_LABELS } from '@/constants/project';
import type { Project, Deployment } from '@/lib/types';
import { cn } from '@/lib/tailwind-utils';

// ─── Deploy Status Config ────────────────────────────────────────────────────

const DEPLOY_STATUS_CONFIG: Record<
  string,
  { Icon: React.ComponentType<{ size?: number; color?: string; strokeWidth?: number }>; color: string }
> = {
  success: { Icon: CheckCircle2, color: '#16a34a' },
  failed: { Icon: XCircle, color: '#dc2626' },
  'in-progress': { Icon: Loader2, color: '#ca8a04' },
};

// ─── Component ───────────────────────────────────────────────────────────────

interface OverviewSectionProps {
  project: Project;
  deployments: Deployment[];
}

export function OverviewSection({ project, deployments }: OverviewSectionProps) {
  const isRunning = project.status === 'running';

  return (
    <View className="gap-6">
      {/* Stat Cards Grid */}
      <View className="flex-row flex-wrap gap-4">
        <MiniStatCard
          label="Status"
          value={project.status.charAt(0).toUpperCase() + project.status.slice(1)}
          Icon={Settings}
        />
        <MiniStatCard label="Uptime" value={project.uptime} Icon={Activity} />
        <MiniStatCard
          label="CPU Usage"
          value={isRunning ? `${project.cpu}%` : '\u2014'}
          Icon={Cpu}
        />
        <MiniStatCard
          label="Memory"
          value={isRunning ? `${project.memory}%` : '\u2014'}
          Icon={Server}
        />
      </View>

      {/* Resource Usage */}
      {isRunning && (
        <Card>
          <CardHeader
            title="Resource Usage"
            subtitle={`Live resource utilization across ${project.instances} instance${project.instances !== 1 ? 's' : ''}`}
          />
          <CardContent>
            <ProgressBar label="CPU" value={project.cpu} />
            <View className="mt-4" />
            <ProgressBar
              label="Memory"
              value={project.memory}
              colorThresholds={{ high: '#ef4444', medium: '#eab308', low: '#3b82f6' }}
            />
          </CardContent>
        </Card>
      )}

      {/* Recent Deployments */}
      {deployments.length > 0 && (
        <Card>
          <CardHeader
            title="Recent Deployments"
            subtitle="Latest deployment activity"
          />
          <View>
            {deployments.slice(0, 4).map((dep, i) => {
              const cfg = DEPLOY_STATUS_CONFIG[dep.status] ?? DEPLOY_STATUS_CONFIG.success;
              return (
                <View
                  key={dep.id}
                  className={cn(
                    'flex-row items-start gap-4 px-6 py-4',
                    i > 0 && 'border-t border-neutral-200 dark:border-neutral-700'
                  )}
                >
                  <cfg.Icon size={16} color={cfg.color} strokeWidth={2} />
                  <View className="flex-1">
                    <Text className="text-sm font-medium text-neutral-900 dark:text-white" numberOfLines={1}>
                      {dep.message}
                    </Text>
                    <View className="flex-row gap-3 flex-wrap mt-0.5">
                      <MetaBit icon={GitCommit} text={dep.commit} />
                      <MetaBit icon={GitBranch} text={dep.branch} />
                      <MetaBit icon={User} text={dep.deployedBy} />
                    </View>
                  </View>
                  <View className="items-end gap-1">
                    <Text className="text-xs text-neutral-500 dark:text-neutral-400">{dep.createdAt}</Text>
                    <Text className="text-xs text-neutral-500 dark:text-neutral-400">{dep.duration}</Text>
                  </View>
                </View>
              );
            })}
          </View>
        </Card>
      )}

      {/* Service Info */}
      <Card>
        <CardHeader title="Service Info" />
        <CardContent>
          <InfoRow label="Region" value={project.region} />
          <InfoRow label="Instances" value={String(project.instances)} />
          <InfoRow
            label="Type"
            value={TYPE_LABELS[project.type] ?? project.type}
          />
          {project.url && <InfoRow label="URL" value={project.url} />}
          <InfoRow label="Last deployed" value={project.lastDeployed} />
          <InfoRow label="Deployed by" value={project.lastDeployedBy} />
        </CardContent>
      </Card>
    </View>
  );
}

// ─── MiniStatCard ────────────────────────────────────────────────────────────

function MiniStatCard({
  label,
  value,
  Icon,
}: {
  label: string;
  value: string;
  Icon: React.ComponentType<{ size?: number; color?: string; strokeWidth?: number }>;
}) {
  return (
    <View className="flex-1 min-w-[45%] bg-white dark:bg-neutral-900 border border-neutral-200 dark:border-neutral-800 rounded-2xl py-6 px-6 shadow-sm">
      <View className="gap-2">
        <View className="flex-row items-center gap-1.5">
          <Icon size={14} color="#999" strokeWidth={2} />
          <Text className="text-sm text-neutral-500 dark:text-neutral-400">{label}</Text>
        </View>
        <Text className="text-xl font-semibold text-neutral-900 dark:text-white leading-7">
          {value}
        </Text>
      </View>
    </View>
  );
}

// ─── InfoRow ─────────────────────────────────────────────────────────────────

function InfoRow({
  label,
  value,
}: {
  label: string;
  value: string;
}) {
  return (
    <View className="flex-row justify-between items-center py-2 gap-4">
      <Text className="text-sm text-neutral-500 dark:text-neutral-400">{label}</Text>
      <Text className="text-sm font-medium text-neutral-900 dark:text-white flex-1 text-right" numberOfLines={1}>
        {value}
      </Text>
    </View>
  );
}

// ─── MetaBit ─────────────────────────────────────────────────────────────────

function MetaBit({
  icon: Icon,
  text,
}: {
  icon: React.ComponentType<{ size?: number; color?: string; strokeWidth?: number }>;
  text: string;
}) {
  return (
    <View className="flex-row items-center gap-1">
      <Icon size={12} color="#999" strokeWidth={2} />
      <Text className="text-xs text-neutral-500 dark:text-neutral-400">{text}</Text>
    </View>
  );
}

// ─── Styles ──────────────────────────────────────────────────────────────────
// All styling is now handled via Tailwind CSS classes
