// ─── EnvironmentSection ─────────────────────────────────────────────────────
// Environment variable manager: add, reveal/mask, and delete variables.

import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  TextInput,
  Alert,
} from 'react-native';
import { Eye, EyeOff, Trash2, Plus, X } from 'lucide-react-native';

import { Card, CardHeader, CardContent } from '@/components/ui/card';
import { cn } from '@/lib/tailwind-utils';

interface EnvVar {
  key: string;
  value: string;
}

const SEED_ENV_VARS: EnvVar[] = [
  { key: 'NODE_ENV', value: 'production' },
  { key: 'PORT', value: '8080' },
  { key: 'DATABASE_URL', value: 'postgres://user:pass@host:5432/db' },
  { key: 'API_SECRET', value: 'sk_live_abc123xyz789' },
  { key: 'REDIS_URL', value: 'redis://localhost:6379' },
];

const SENSITIVE_KEYWORDS = ['SECRET', 'KEY', 'TOKEN', 'PASS', 'PASSWORD', 'URL'];

export function EnvironmentSection() {
  const [vars, setVars] = useState<EnvVar[]>(SEED_ENV_VARS);
  const [revealed, setRevealed] = useState<Set<string>>(new Set());
  const [showAdd, setShowAdd] = useState(false);
  const [newKey, setNewKey] = useState('');
  const [newValue, setNewValue] = useState('');

  const isSensitive = (key: string) =>
    SENSITIVE_KEYWORDS.some(s => key.toUpperCase().includes(s));

  const maskValue = (value: string) => '\u2022'.repeat(Math.min(value.length, 20));

  const toggleReveal = (key: string) => {
    setRevealed(prev => {
      const next = new Set(prev);
      next.has(key) ? next.delete(key) : next.add(key);
      return next;
    });
  };

  const addVar = () => {
    if (!newKey.trim()) return;
    setVars(prev => [...prev, { key: newKey.trim(), value: newValue.trim() }]);
    setNewKey('');
    setNewValue('');
    setShowAdd(false);
  };

  const deleteVar = (key: string) => {
    Alert.alert('Remove Variable', `Remove "${key}"?`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Remove',
        style: 'destructive',
        onPress: () => setVars(prev => prev.filter(v => v.key !== key)),
      },
    ]);
  };

  const inputStyle = cn(
    'border border-neutral-200 dark:border-neutral-700',
    'bg-white dark:bg-neutral-900',
    'text-neutral-900 dark:text-white',
    'rounded-lg px-3 py-2 text-sm font-mono'
  );

  return (
    <Card>
      <CardHeader
        title="Environment Variables"
        subtitle={`${vars.length} variables configured`}
      >
        <TouchableOpacity
          className="flex-row items-center gap-1 px-3 py-1.5 rounded-md bg-blue-600"
          onPress={() => setShowAdd(v => !v)}
        >
          {showAdd ? (
            <X size={16} color="#fff" strokeWidth={2} />
          ) : (
            <Plus size={16} color="#fff" strokeWidth={2} />
          )}
          <Text className="text-white text-xs font-semibold">{showAdd ? 'Cancel' : 'Add'}</Text>
        </TouchableOpacity>
      </CardHeader>

      <CardContent>
        {/* Add form */}
        {showAdd && (
          <View
            className={cn(
              'gap-2 p-3 rounded-lg border border-neutral-200 dark:border-neutral-700',
              'bg-neutral-50 dark:bg-neutral-800'
            )}
          >
            <TextInput
              className={inputStyle}
              placeholder="KEY_NAME"
              placeholderTextColor="#999"
              value={newKey}
              onChangeText={setNewKey}
              autoCapitalize="characters"
            />
            <TextInput
              className={inputStyle}
              placeholder="value"
              placeholderTextColor="#999"
              value={newValue}
              onChangeText={setNewValue}
              autoCapitalize="none"
            />
            <TouchableOpacity
              className="h-9 rounded-lg bg-blue-600 items-center justify-center"
              onPress={addVar}
            >
              <Text className="text-white text-xs font-semibold">Save Variable</Text>
            </TouchableOpacity>
          </View>
        )}

        {/* Variable list */}
        <View>
          {vars.map((v, i) => {
            const sensitive = isSensitive(v.key);
            const visible = revealed.has(v.key);
            return (
              <View
                key={v.key}
                className={cn(
                  'flex-row items-center py-3 gap-2.5',
                  i > 0 && 'border-t border-neutral-200 dark:border-neutral-700'
                )}
              >
                <View className="flex-1 gap-0.75">
                  <Text className="text-sm font-semibold font-mono text-neutral-900 dark:text-white">{v.key}</Text>
                  <Text className="text-xs font-mono text-neutral-500 dark:text-neutral-400" numberOfLines={1}>
                    {sensitive && !visible ? maskValue(v.value) : v.value}
                  </Text>
                </View>
                <View className="flex-row items-center gap-3">
                  {sensitive && (
                    <TouchableOpacity onPress={() => toggleReveal(v.key)} hitSlop={8}>
                      {visible ? (
                        <EyeOff size={17} color="#999" strokeWidth={2} />
                      ) : (
                        <Eye size={17} color="#999" strokeWidth={2} />
                      )}
                    </TouchableOpacity>
                  )}
                  <TouchableOpacity onPress={() => deleteVar(v.key)} hitSlop={8}>
                    <Trash2 size={17} color="#999" strokeWidth={2} />
                  </TouchableOpacity>
                </View>
              </View>
            );
          })}
        </View>
      </CardContent>
    </Card>
  );
}

// ─── Styles ──────────────────────────────────────────────────────────────────
// All styling is now handled via Tailwind CSS classes
