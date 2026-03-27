// ─── DeploymentConfigForm ───────────────────────────────────────────────────
// Form section for service type, region, instances, and branch.

import React from 'react';
import { View, Text, TouchableOpacity, TextInput } from 'react-native';
import { cn } from '@/lib/tailwind-utils';
import { Card, CardHeader, CardContent } from '@/components/ui/card';
import { FieldLabel } from '@/components/ui/field-label';
import { PROJECT_TYPE_OPTIONS, REGIONS } from '@/constants/project';
import type { ProjectType } from '@/lib/types';

interface DeploymentConfigFormProps {
  type: ProjectType;
  onTypeChange: (value: ProjectType) => void;
  region: string;
  onRegionChange: (value: string) => void;
  instances: string;
  onInstancesChange: (value: string) => void;
  branch: string;
  onBranchChange: (value: string) => void;
  className?: string;
}

export function DeploymentConfigForm({
  type,
  onTypeChange,
  region,
  onRegionChange,
  instances,
  onInstancesChange,
  branch,
  onBranchChange,
  className,
}: DeploymentConfigFormProps) {
  const inputClassName = cn(
    'w-full h-9 px-3 py-2',
    'bg-white dark:bg-neutral-900',
    'border border-gray-200 dark:border-neutral-800',
    'rounded-lg',
    'text-neutral-900 dark:text-white',
    'placeholder:text-gray-500 dark:placeholder:text-neutral-400'
  );

  return (
    <Card className={className}>
      <CardHeader
        title="Deployment Configuration"
        subtitle="Choose type, region, and scale"
      />
      <CardContent>
        {/* Type Selector */}
        <View className="gap-2 mb-6">
          <FieldLabel label="Service Type" />
          <View className="flex-row flex-wrap gap-2">
            {PROJECT_TYPE_OPTIONS.map(t => (
              <TouchableOpacity
                key={t.value}
                className={cn(
                  'flex flex-row items-center gap-1.5 px-3 py-2 rounded-lg border',
                  type === t.value
                    ? 'bg-indigo-100 dark:bg-indigo-950 border-indigo-600 dark:border-indigo-500'
                    : 'bg-white dark:bg-neutral-900 border-gray-200 dark:border-neutral-800'
                )}
                onPress={() => onTypeChange(t.value)}
              >
                <t.Icon
                  size={18}
                  color={type === t.value ? '#4f46e5' : '#71717a'}
                  strokeWidth={2}
                />
                <Text
                  className={cn(
                    'text-xs font-medium',
                    type === t.value
                      ? 'text-indigo-600 dark:text-indigo-400'
                      : 'text-neutral-900 dark:text-white'
                  )}
                >
                  {t.label}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        </View>

        {/* Region Selector */}
        <View className="gap-2 mb-6">
          <FieldLabel label="Region" />
          <View className="gap-2">
            {REGIONS.map(r => (
              <TouchableOpacity
                key={r.value}
                className={cn(
                  'flex flex-row items-center gap-2.5 px-3 py-2.5 rounded-lg border',
                  region === r.value
                    ? 'bg-indigo-100 dark:bg-indigo-950 border-indigo-600 dark:border-indigo-500'
                    : 'bg-white dark:bg-neutral-900 border-gray-200 dark:border-neutral-800'
                )}
                onPress={() => onRegionChange(r.value)}
              >
                <View
                  className={cn(
                    'w-4.5 h-4.5 rounded-full border-2 flex items-center justify-center',
                    region === r.value
                      ? 'border-indigo-600 dark:border-indigo-500'
                      : 'border-gray-200 dark:border-neutral-800'
                  )}
                >
                  {region === r.value && (
                    <View className="w-2 h-2 rounded-full bg-indigo-600 dark:bg-indigo-500" />
                  )}
                </View>
                <Text className="text-sm text-neutral-900 dark:text-white">
                  {r.label}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        </View>

        {/* Instances + Branch */}
        <View className="flex-row gap-4">
          <View className="flex-1 gap-2">
            <FieldLabel label="Instances" />
            <TextInput
              className={inputClassName}
              value={instances}
              onChangeText={onInstancesChange}
              placeholder="1"
              placeholderTextColor="#999"
              keyboardType="number-pad"
            />
          </View>
          <View className="flex-1 gap-2">
            <FieldLabel label="Branch" />
            <TextInput
              className={inputClassName}
              value={branch}
              onChangeText={onBranchChange}
              placeholder="main"
              placeholderTextColor="#999"
              autoCapitalize="none"
            />
          </View>
        </View>
      </CardContent>
    </Card>
  );
}
