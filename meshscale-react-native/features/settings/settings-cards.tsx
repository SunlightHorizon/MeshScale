// ─── Settings Cards ─────────────────────────────────────────────────────────
// Profile, Preferences, and Security cards for the Settings screen.

import React from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  TextInput,
  Switch,
  Alert,
} from 'react-native';
import { Card, CardHeader, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/tailwind-utils';

// ─── SwitchRow ───────────────────────────────────────────────────────────────

function SwitchRow({
  label,
  description,
  value,
  onValueChange,
  tint,
}: {
  label: string;
  description: string;
  value: boolean;
  onValueChange: (v: boolean) => void;
  tint: string;
}) {
  return (
    <View className="flex flex-row items-center justify-between gap-4">
      <View className="flex-1 gap-0.5">
        <Text className="text-sm font-medium text-neutral-900 dark:text-white">{label}</Text>
        <Text className="text-sm leading-5 text-neutral-500 dark:text-neutral-400">{description}</Text>
      </View>
      <Switch
        value={value}
        onValueChange={onValueChange}
        trackColor={{ false: '#e5e7eb', true: tint }}
        thumbColor="#fff"
      />
    </View>
  );
}

// ─── ProfileCard ─────────────────────────────────────────────────────────────

interface ProfileCardProps {
  name: string;
  onNameChange: (v: string) => void;
  email: string;
  onEmailChange: (v: string) => void;
}

export function ProfileCard({ name, onNameChange, email, onEmailChange }: ProfileCardProps) {
  return (
    <Card>
      <CardHeader
        title="Profile"
        subtitle="Update your profile information"
      />
      <CardContent>
        <View className="gap-2">
          <Text className="text-sm font-medium text-neutral-900 dark:text-white">Name</Text>
          <TextInput
            className="h-9 rounded-lg border border-gray-200 bg-white px-3 text-sm text-neutral-900 placeholder-neutral-500 dark:border-neutral-800 dark:bg-neutral-900 dark:text-white dark:placeholder-neutral-400"
            value={name}
            onChangeText={onNameChange}
            placeholder="Enter your name"
            placeholderTextColor="#a3a3a3"
          />
        </View>
        <View className="gap-2">
          <Text className="text-sm font-medium text-neutral-900 dark:text-white">Email</Text>
          <TextInput
            className="h-9 rounded-lg border border-gray-200 bg-white px-3 text-sm text-neutral-900 placeholder-neutral-500 dark:border-neutral-800 dark:bg-neutral-900 dark:text-white dark:placeholder-neutral-400"
            value={email}
            onChangeText={onEmailChange}
            placeholder="Enter your email"
            placeholderTextColor="#a3a3a3"
            keyboardType="email-address"
            autoCapitalize="none"
          />
        </View>
        <Button
          variant="default"
          size="sm"
          onPress={() => Alert.alert('Saved', 'Profile updated successfully.')}
        >
          Save Changes
        </Button>
      </CardContent>
    </Card>
  );
}

// ─── PreferencesCard ─────────────────────────────────────────────────────────

interface PreferencesCardProps {
  emailNotifs: boolean;
  onEmailNotifsChange: (v: boolean) => void;
  marketingEmails: boolean;
  onMarketingEmailsChange: (v: boolean) => void;
  darkMode: boolean;
  onDarkModeChange: (v: boolean) => void;
}

export function PreferencesCard({
  emailNotifs,
  onEmailNotifsChange,
  marketingEmails,
  onMarketingEmailsChange,
  darkMode,
  onDarkModeChange,
}: PreferencesCardProps) {
  return (
    <Card>
      <CardHeader
        title="Preferences"
        subtitle="Customize your experience"
      />
      <CardContent>
        <SwitchRow
          label="Email Notifications"
          description="Receive email notifications about your account"
          value={emailNotifs}
          onValueChange={onEmailNotifsChange}
          tint="#4f46e5"
        />
        <View className="h-px bg-gray-200 dark:bg-neutral-800" />
        <SwitchRow
          label="Marketing Emails"
          description="Receive emails about new features and updates"
          value={marketingEmails}
          onValueChange={onMarketingEmailsChange}
          tint="#4f46e5"
        />
        <View className="h-px bg-gray-200 dark:bg-neutral-800" />
        <SwitchRow
          label="Dark Mode"
          description="Use dark theme across the application"
          value={darkMode}
          onValueChange={onDarkModeChange}
          tint="#4f46e5"
        />
      </CardContent>
    </Card>
  );
}

// ─── SecurityCard ────────────────────────────────────────────────────────────

interface SecurityCardProps {}

export function SecurityCard({}: SecurityCardProps) {
  return (
    <Card>
      <CardHeader
        title="Security"
        subtitle="Manage your security settings"
      />
      <CardContent>
        <View className="gap-2">
          <Text className="text-sm font-medium text-neutral-900 dark:text-white">Current Password</Text>
          <TextInput
            className="h-9 rounded-lg border border-gray-200 bg-white px-3 text-sm text-neutral-900 placeholder-neutral-500 dark:border-neutral-800 dark:bg-neutral-900 dark:text-white dark:placeholder-neutral-400"
            placeholder={"\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022"}
            placeholderTextColor="#a3a3a3"
            secureTextEntry
          />
        </View>
        <View className="gap-2">
          <Text className="text-sm font-medium text-neutral-900 dark:text-white">New Password</Text>
          <TextInput
            className="h-9 rounded-lg border border-gray-200 bg-white px-3 text-sm text-neutral-900 placeholder-neutral-500 dark:border-neutral-800 dark:bg-neutral-900 dark:text-white dark:placeholder-neutral-400"
            placeholder={"\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022"}
            placeholderTextColor="#a3a3a3"
            secureTextEntry
          />
        </View>
        <View className="gap-2">
          <Text className="text-sm font-medium text-neutral-900 dark:text-white">Confirm Password</Text>
          <TextInput
            className="h-9 rounded-lg border border-gray-200 bg-white px-3 text-sm text-neutral-900 placeholder-neutral-500 dark:border-neutral-800 dark:bg-neutral-900 dark:text-white dark:placeholder-neutral-400"
            placeholder={"\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022"}
            placeholderTextColor="#a3a3a3"
            secureTextEntry
          />
        </View>
        <Button
          variant="default"
          size="sm"
          onPress={() => Alert.alert('Updated', 'Password changed successfully.')}
        >
          Update Password
        </Button>
      </CardContent>
    </Card>
  );
}


