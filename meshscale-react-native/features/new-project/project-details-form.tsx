// ─── ProjectDetailsForm ─────────────────────────────────────────────────────
// Form section for project name and description in the new project screen.

import React from 'react';
import { View, TextInput } from 'react-native';
import { cn } from '@/lib/tailwind-utils';
import { Card, CardHeader, CardContent } from '@/components/ui/card';
import { FieldLabel } from '@/components/ui/field-label';

interface ProjectDetailsFormProps {
  name: string;
  onNameChange: (value: string) => void;
  description: string;
  onDescriptionChange: (value: string) => void;
  className?: string;
}

export function ProjectDetailsForm({
  name,
  onNameChange,
  description,
  onDescriptionChange,
  className,
}: ProjectDetailsFormProps) {
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
        title="Project Details"
        subtitle="Basic info about your deployment"
      />
      <CardContent>
        <View className="gap-2 mb-4">
          <FieldLabel label="Project Name *" />
          <TextInput
            className={inputClassName}
            value={name}
            onChangeText={onNameChange}
            placeholder="e.g. my-api-service"
            placeholderTextColor="#999"
            autoCapitalize="none"
          />
        </View>
        <View className="gap-2">
          <FieldLabel label="Description" />
          <TextInput
            className={cn(inputClassName, 'h-[72px] py-2')}
            value={description}
            onChangeText={onDescriptionChange}
            placeholder="Optional project description"
            placeholderTextColor="#999"
            multiline
            numberOfLines={3}
            textAlignVertical="top"
          />
        </View>
      </CardContent>
    </Card>
  );
}
