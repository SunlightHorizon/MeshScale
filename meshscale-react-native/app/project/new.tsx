// ─── New Project Screen ──────────────────────────────────────────────────────
// Form for creating a new project with deployment configuration.

import React, { useState } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  Alert,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { ChevronLeft, Loader2, Rocket } from 'lucide-react-native';
import { router } from 'expo-router';

import { useStore } from '@/lib/store';
import { useLargeScreen } from '@/hooks/use-large-screen';
import { Button } from '@/components/ui/button';
import { ProjectDetailsForm } from '@/features/new-project/project-details-form';
import { DeploymentConfigForm } from '@/features/new-project/deployment-config-form';
import type { Project, Deployment, ProjectType } from '@/lib/types';

export default function NewProjectScreen() {
  const { addProject, addDeployment } = useStore();
  const isLargeScreen = useLargeScreen();

  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [type, setType] = useState<ProjectType>('website');
  const [region, setRegion] = useState('us-east-1');
  const [instances, setInstances] = useState('1');
  const [branch, setBranch] = useState('main');
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = () => {
    if (!name.trim()) {
      Alert.alert('Validation', 'Project name is required.');
      return;
    }

    setSubmitting(true);

    const projectId = name
      .toLowerCase()
      .trim()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-|-$/g, '');

    const project: Project = {
      id: projectId,
      name: name.trim(),
      description: description.trim() || `Deployed from branch ${branch}`,
      type,
      status: 'deploying',
      region,
      uptime: '\u2014',
      lastDeployed: 'Just now',
      lastDeployedBy: 'Eddie Lake',
      cpu: 0,
      memory: 0,
      instances: parseInt(instances, 10) || 1,
    };

    const deployment: Deployment = {
      id: `dep-${Date.now()}`,
      projectId,
      commit: Math.random().toString(36).slice(2, 9),
      branch,
      message: 'Initial deployment',
      status: 'in-progress',
      createdAt: 'Just now',
      duration: '-',
      deployedBy: 'Eddie Lake',
    };

    addProject(project);
    addDeployment(deployment);

    setTimeout(() => {
      setSubmitting(false);
      router.replace(`/project/${projectId}` as any);
    }, 300);
  };

  return (
    <SafeAreaView className="flex-1 bg-white dark:bg-neutral-900">
      {/* Header */}
      <View className="flex flex-row items-center justify-between border-b border-gray-200 px-4 py-3 dark:border-neutral-800">
        <TouchableOpacity className="flex flex-row items-center gap-0.5 w-20" onPress={() => router.back()}>
          <ChevronLeft size={22} color="#4f46e5" strokeWidth={2} />
          <Text className="text-sm font-medium text-indigo-600 dark:text-indigo-400">Projects</Text>
        </TouchableOpacity>
        <Text className="text-base font-medium text-neutral-900 dark:text-white">New Project</Text>
        <View style={{ width: 80 }} />
      </View>

      <ScrollView contentContainerStyle={{ padding: 16, gap: 24 }} showsVerticalScrollIndicator={false}>
        <View className={isLargeScreen ? 'w-full max-w-3xl self-center gap-6' : ''}>
          <ProjectDetailsForm
            name={name}
            onNameChange={setName}
            description={description}
            onDescriptionChange={setDescription}
          />

          <DeploymentConfigForm
            type={type}
            onTypeChange={setType}
            region={region}
            onRegionChange={setRegion}
            instances={instances}
            onInstancesChange={setInstances}
            branch={branch}
            onBranchChange={setBranch}
          />

          {/* Separator */}
          <View className="h-px bg-gray-200 dark:bg-neutral-800" />

          {/* Footer */}
          <View className="flex flex-row items-center justify-between gap-3">
            <View className="flex-1">
              <Button
                variant="outline"
                size="default"
                onPress={() => router.back()}
              >
                Cancel
              </Button>
            </View>
            <View className="flex-1">
              <Button
                variant="default"
                size="default"
                onPress={handleSubmit}
                disabled={submitting}
              >
                {submitting ? (
                  <>
                    <Loader2 size={18} color="#fff" strokeWidth={2} />
                    <Text className="text-sm font-medium text-white">Creating...</Text>
                  </>
                ) : (
                  <>
                    <Rocket size={18} color="#fff" strokeWidth={2} />
                    <Text className="text-sm font-medium text-white">Deploy Project</Text>
                  </>
                )}
              </Button>
            </View>
          </View>
        </View>
        <View style={{ height: 20 }} />
      </ScrollView>
    </SafeAreaView>
  );
}
