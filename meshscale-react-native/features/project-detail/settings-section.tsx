// ─── ProjectSettingsSection ─────────────────────────────────────────────────
// Project settings: general info, deployment config, and danger zone.

import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  TextInput,
  Alert,
} from 'react-native';
import { CheckCircle2, XCircle, Trash2 } from 'lucide-react-native';
import { router } from 'expo-router';

import { useStore } from '@/lib/store';
import { Card, CardHeader, CardContent } from '@/components/ui/card';
import type { Project } from '@/lib/types';
import { cn } from '@/lib/tailwind-utils';

interface SettingsSectionProps {
  project: Project;
}

export function ProjectSettingsSection({ project }: SettingsSectionProps) {
  const { updateProject } = useStore();
  const [name, setName] = useState(project.name);
  const [description, setDescription] = useState(project.description);
  const [instances, setInstances] = useState(String(project.instances));

  const saveGeneral = () => {
    if (!name.trim()) {
      Alert.alert('Validation', 'Project name cannot be empty.');
      return;
    }
    updateProject(project.id, { name: name.trim(), description: description.trim() });
    Alert.alert('Saved', 'Project details updated.');
  };

  const saveDeployment = () => {
    const n = parseInt(instances, 10);
    if (isNaN(n) || n < 1) {
      Alert.alert('Validation', 'Instances must be a positive number.');
      return;
    }
    updateProject(project.id, { instances: n });
    Alert.alert('Saved', 'Deployment config updated.');
  };

  const confirmDelete = () => {
    Alert.alert(
      'Delete Project',
      `Permanently delete "${project.name}" and all its deployments? This cannot be undone.`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: () => router.replace('/(tabs)/projects'),
        },
      ],
    );
  };

  const toggleService = () => {
    const next = project.status === 'running' ? 'stopped' : 'running';
    updateProject(project.id, { status: next });
    Alert.alert(
      next === 'running' ? 'Started' : 'Stopped',
      `${project.name} is now ${next}.`,
    );
  };

  const inputStyle = cn(
    'border border-neutral-200 dark:border-neutral-700',
    'bg-white dark:bg-neutral-900',
    'text-neutral-900 dark:text-white',
    'rounded-lg px-3 py-2 text-sm'
  );

  return (
    <View className="gap-6">
      {/* General */}
      <Card>
        <CardHeader title="General" />
        <CardContent>
          <View className="gap-2">
            <Text className="text-sm font-medium text-neutral-900 dark:text-white">Project Name</Text>
            <TextInput 
              className={inputStyle}
              value={name} 
              onChangeText={setName} 
            />
          </View>
          <View className="gap-2 mt-4">
            <Text className="text-sm font-medium text-neutral-900 dark:text-white">Description</Text>
            <TextInput
              className={cn(inputStyle, 'min-h-[70px] pt-2')}
              value={description}
              onChangeText={setDescription}
              multiline
              numberOfLines={3}
              textAlignVertical="top"
            />
          </View>
          <TouchableOpacity
            className="h-9 rounded-lg bg-blue-600 items-center justify-center mt-4"
            onPress={saveGeneral}
          >
            <Text className="text-white text-sm font-medium">Save Changes</Text>
          </TouchableOpacity>
        </CardContent>
      </Card>

      {/* Deployment Config */}
      <Card>
        <CardHeader title="Deployment" />
        <CardContent>
          <View className="flex-row justify-between py-2">
            <Text className="text-sm text-neutral-500 dark:text-neutral-400">Region</Text>
            <Text className="text-sm font-medium text-neutral-900 dark:text-white">{project.region}</Text>
          </View>
          <View className="h-px bg-neutral-200 dark:bg-neutral-700" />
          <View className="flex-row justify-between py-2">
            <Text className="text-sm text-neutral-500 dark:text-neutral-400">Type</Text>
            <Text className="text-sm font-medium text-neutral-900 dark:text-white">
              {project.type.charAt(0).toUpperCase() + project.type.slice(1)}
            </Text>
          </View>
          <View className="h-px bg-neutral-200 dark:bg-neutral-700" />
          <View className="gap-2 mt-4">
            <Text className="text-sm font-medium text-neutral-900 dark:text-white">Instances</Text>
            <TextInput
              className={cn(inputStyle, 'w-20')}
              value={instances}
              onChangeText={setInstances}
              keyboardType="number-pad"
            />
          </View>
          <TouchableOpacity
            className="h-9 rounded-lg bg-blue-600 items-center justify-center mt-4"
            onPress={saveDeployment}
          >
            <Text className="text-white text-sm font-medium">Save Config</Text>
          </TouchableOpacity>
        </CardContent>
      </Card>

      {/* Danger Zone */}
      <Card>
        <CardHeader title="Danger Zone" />
        <CardContent>
          <View className="flex-row items-center gap-3">
            <View className="flex-1 gap-1">
              <Text className="text-sm font-medium text-neutral-900 dark:text-white">
                {project.status === 'running' ? 'Stop Service' : 'Start Service'}
              </Text>
              <Text className="text-xs text-neutral-500 dark:text-neutral-400">
                {project.status === 'running'
                  ? 'Halt all running instances immediately'
                  : 'Restart the service'}
              </Text>
            </View>
            <TouchableOpacity
              className={cn(
                'flex-row items-center gap-1.5 px-3 py-1.5 rounded-md border',
                project.status === 'running'
                  ? 'bg-red-50 dark:bg-red-900/10 border-red-300 dark:border-red-700'
                  : 'bg-green-50 dark:bg-green-900/10 border-green-300 dark:border-green-700'
              )}
              onPress={toggleService}
            >
              {project.status === 'running' ? (
                <XCircle size={15} color="#dc2626" strokeWidth={2} />
              ) : (
                <CheckCircle2 size={15} color="#15803d" strokeWidth={2} />
              )}
              <Text
                className="text-xs font-semibold"
                style={{ color: project.status === 'running' ? '#dc2626' : '#15803d' }}
              >
                {project.status === 'running' ? 'Stop' : 'Start'}
              </Text>
            </TouchableOpacity>
          </View>

          <View className="h-px bg-red-300 dark:bg-red-700 my-3" />

          <View className="flex-row items-center gap-3">
            <View className="flex-1 gap-1">
              <Text className="text-sm font-medium text-neutral-900 dark:text-white">Delete Project</Text>
              <Text className="text-xs text-neutral-500 dark:text-neutral-400">
                Permanently remove this project and all data
              </Text>
            </View>
            <TouchableOpacity
              className="flex-row items-center gap-1.5 px-3 py-1.5 rounded-md border bg-red-50 dark:bg-red-900/10 border-red-300 dark:border-red-700"
              onPress={confirmDelete}
            >
              <Trash2 size={15} color="#dc2626" strokeWidth={2} />
              <Text className="text-xs font-semibold text-red-600 dark:text-red-400">Delete</Text>
            </TouchableOpacity>
          </View>
        </CardContent>
      </Card>
    </View>
  );
}

// ─── Styles ──────────────────────────────────────────────────────────────────
// All styling is now handled via Tailwind CSS classes
