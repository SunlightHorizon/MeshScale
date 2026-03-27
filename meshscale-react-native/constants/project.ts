// ─── Project Constants ───────────────────────────────────────────────────────
// Shared labels, icons, and config for project types and regions.
// Used by: projects list, project detail, new project form.

import React from 'react';
import {
  Globe,
  Gamepad2,
  Code2,
  Cpu,
  Clock,
} from 'lucide-react-native';
import { ProjectType } from '@/lib/types';

// ─── Type Labels ─────────────────────────────────────────────────────────────

export const TYPE_LABELS: Record<ProjectType, string> = {
  website: 'Website',
  'game-server': 'Game Server',
  api: 'API',
  worker: 'Worker',
  cron: 'Cron Job',
};

// ─── Type Icons ──────────────────────────────────────────────────────────────

type IconComponent = React.ComponentType<{
  size?: number;
  color?: string;
  strokeWidth?: number;
}>;

export const TYPE_ICONS: Record<ProjectType, IconComponent> = {
  website: Globe,
  'game-server': Gamepad2,
  api: Code2,
  worker: Cpu,
  cron: Clock,
};

// ─── Regions ─────────────────────────────────────────────────────────────────

export const REGIONS = [
  { value: 'us-east-1', label: 'US East (N. Virginia)' },
  { value: 'us-west-2', label: 'US West (Oregon)' },
  { value: 'eu-west-1', label: 'EU West (Ireland)' },
  { value: 'ap-southeast-1', label: 'Asia Pacific (Singapore)' },
] as const;

// ─── Project Type Options (for forms) ────────────────────────────────────────

export const PROJECT_TYPE_OPTIONS: {
  value: ProjectType;
  label: string;
  Icon: IconComponent;
}[] = [
  { value: 'website', label: 'Website', Icon: Globe },
  { value: 'api', label: 'API', Icon: Code2 },
  { value: 'game-server', label: 'Game Server', Icon: Gamepad2 },
  { value: 'worker', label: 'Worker', Icon: Cpu },
  { value: 'cron', label: 'Cron Job', Icon: Clock },
];
