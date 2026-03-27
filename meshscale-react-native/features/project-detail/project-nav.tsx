// ─── ProjectNav ─────────────────────────────────────────────────────────────
// Navigation for project detail: sidebar panel on large screens, horizontal
// tab bar on small screens.

import React from 'react';
import { View, Text, ScrollView, TouchableOpacity } from 'react-native';
import {
  LayoutDashboard,
  Rocket,
  FileText,
  KeyRound,
  Settings,
  MapPin,
  Server,
  Link,
} from 'lucide-react-native';
import { cn } from '@/lib/tailwind-utils';

import { TypeIcon } from '@/components/shared/type-icon';
import { TYPE_LABELS } from '@/constants/project';
import type { Project } from '@/lib/types';

export type Section = 'overview' | 'deployments' | 'logs' | 'environment' | 'settings-section';

const NAV_ITEMS: {
  id: Section;
  label: string;
  Icon: React.ComponentType<{ size?: number; color?: string; strokeWidth?: number }>;
}[] = [
  { id: 'overview', label: 'Overview', Icon: LayoutDashboard },
  { id: 'deployments', label: 'Deployments', Icon: Rocket },
  { id: 'logs', label: 'Logs', Icon: FileText },
  { id: 'environment', label: 'Environment', Icon: KeyRound },
  { id: 'settings-section', label: 'Settings', Icon: Settings },
];

// ─── Sidebar Nav (Large Screens) ─────────────────────────────────────────────

interface SidebarNavProps {
  project: Project;
  activeSection: Section;
  onSectionChange: (section: Section) => void;
  className?: string;
}

export function ProjectSidebarNav({
  project,
  activeSection,
  onSectionChange,
  className,
}: SidebarNavProps) {
  return (
    <View
      className={cn(
        'w-64 flex flex-col',
        'bg-gray-50 dark:bg-neutral-800',
        'border-r border-gray-200 dark:border-neutral-800',
        className
      )}
    >
      {/* Nav Items */}
      <View className="px-3 py-3 gap-1">
        {NAV_ITEMS.map(item => {
          const active = activeSection === item.id;
          return (
            <TouchableOpacity
              key={item.id}
              className={cn(
                'flex flex-row items-center gap-2.5 px-3 py-2 rounded-lg border',
                active
                  ? 'bg-white dark:bg-neutral-900 border-gray-200 dark:border-neutral-700 shadow-subtle'
                  : 'border-transparent'
              )}
              onPress={() => onSectionChange(item.id)}
            >
              <item.Icon
                size={16}
                color={active ? '#171717' : '#71717a'}
                strokeWidth={2}
              />
              <Text
                className={cn(
                  'text-sm',
                  active
                    ? 'font-semibold text-neutral-900 dark:text-white'
                    : 'font-medium text-neutral-600 dark:text-neutral-400'
                )}
              >
                {item.label}
              </Text>
            </TouchableOpacity>
          );
        })}
      </View>

      {/* Separator */}
      <View className="h-px mx-3 my-1 bg-gray-200 dark:bg-neutral-700" />

      {/* Project Meta */}
      <View className="px-4 py-4 gap-3">
        <MetaRow icon={MapPin} text={project.region} />
        <MetaRow
          icon={Server}
          text={`${project.instances} ${project.instances === 1 ? 'instance' : 'instances'}`}
        />
        <View className="flex flex-row items-center gap-1.5">
          <TypeIcon type={project.type} size="sm" />
          <Text className="text-xs text-neutral-600 dark:text-neutral-400">
            {TYPE_LABELS[project.type] ?? project.type}
          </Text>
        </View>
        {project.url ? (
          <MetaRow icon={Link} text={project.url} tint />
        ) : null}
      </View>
    </View>
  );
}

// ─── Tab Bar Nav (Small Screens) ─────────────────────────────────────────────

interface TabBarNavProps {
  activeSection: Section;
  onSectionChange: (section: Section) => void;
  className?: string;
}

export function ProjectTabBarNav({
  activeSection,
  onSectionChange,
  className,
}: TabBarNavProps) {
  return (
    <ScrollView
      horizontal
      showsHorizontalScrollIndicator={false}
      className={cn(
        'border-b border-gray-200 dark:border-neutral-800',
        className
      )}
      contentContainerStyle={{ paddingHorizontal: 12 }}
    >
      {NAV_ITEMS.map(item => (
        <TouchableOpacity
          key={item.id}
          className={cn(
            'flex flex-row items-center gap-1 py-3 px-2 mr-0.5',
            activeSection === item.id && 'border-b-2 border-indigo-600 dark:border-indigo-500'
          )}
          onPress={() => onSectionChange(item.id)}
        >
          <item.Icon
            size={15}
            color={activeSection === item.id ? '#4f46e5' : '#71717a'}
            strokeWidth={2}
          />
          <Text
            className={cn(
              'text-xs font-medium',
              activeSection === item.id
                ? 'text-indigo-600 dark:text-indigo-400'
                : 'text-neutral-600 dark:text-neutral-400'
            )}
          >
            {item.label}
          </Text>
        </TouchableOpacity>
      ))}
    </ScrollView>
  );
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function MetaRow({
  icon: Icon,
  text,
  tint,
}: {
  icon: React.ComponentType<{ size?: number; color?: string; strokeWidth?: number }>;
  text: string;
  tint?: boolean;
}) {
  const color = tint ? '#4f46e5' : '#71717a';
  const colorClass = tint
    ? 'text-indigo-600 dark:text-indigo-400'
    : 'text-neutral-600 dark:text-neutral-400';

  return (
    <View className="flex flex-row items-center gap-1.5">
      <Icon size={12} color={color} strokeWidth={2} />
      <Text className={cn('text-xs', colorClass)} numberOfLines={1}>
        {text}
      </Text>
    </View>
  );
}
