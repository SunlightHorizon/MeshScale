// ─── FieldLabel ──────────────────────────────────────────────────────────
// Simple form field label. Matches shadcn Label: text-sm font-medium.

import React from 'react';
import { Text } from 'react-native';

interface FieldLabelProps {
  label: string;
  className?: string;
}

export function FieldLabel({ label, className }: FieldLabelProps) {
  return (
    <Text className={className || 'text-sm font-medium text-neutral-900 dark:text-white'}>
      {label}
    </Text>
  );
}
