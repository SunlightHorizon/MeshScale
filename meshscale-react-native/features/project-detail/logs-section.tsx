// ─── LogsSection ────────────────────────────────────────────────────────────
// Live streaming log viewer with level filtering and terminal-style UI.

import React, { useState, useEffect, useRef } from 'react';
import { View, Text, ScrollView, TouchableOpacity } from 'react-native';
import type { Project } from '@/lib/types';
import { cn } from '@/lib/tailwind-utils';

// ─── Log Data ────────────────────────────────────────────────────────────────

const LOG_POOL: { level: string; msg: string }[] = [
  { level: 'info', msg: 'GET /health 200 2ms' },
  { level: 'info', msg: 'GET /api/v1/users 200 14ms' },
  { level: 'info', msg: 'POST /api/v1/deploy 202 8ms' },
  { level: 'info', msg: 'Worker heartbeat OK' },
  { level: 'info', msg: 'GET /api/v1/projects 200 9ms' },
  { level: 'info', msg: 'GET /api/v1/metrics 200 3ms' },
  { level: 'info', msg: 'Task completed in 148ms' },
  { level: 'info', msg: 'Connection re-established' },
  { level: 'info', msg: 'Scheduled task: analytics-flush' },
  { level: 'debug', msg: 'Cache miss: key=session:abc123' },
  { level: 'debug', msg: 'Cache hit: key=user:9f2a' },
  { level: 'debug', msg: 'Queue depth: 3 pending jobs' },
  { level: 'debug', msg: 'DB pool: 4/10 connections active' },
  { level: 'warn', msg: 'Slow query detected: 340ms' },
  { level: 'warn', msg: 'Memory usage at 72% \u2014 approaching limit' },
  { level: 'warn', msg: 'Rate limit approaching: 87/100 req/s' },
  { level: 'error', msg: 'Connection timeout: retry 1/3' },
  { level: 'error', msg: 'Unhandled rejection: TypeError: Cannot read properties of null' },
  { level: 'info', msg: 'Error boundary caught, request recovered' },
  { level: 'info', msg: 'Replica sync complete \u2014 0 drift' },
  { level: 'info', msg: 'POST /api/v1/users 201 22ms' },
  { level: 'debug', msg: 'Evicting 12 stale cache entries' },
  { level: 'warn', msg: 'Disk I/O wait >100ms' },
  { level: 'info', msg: 'DELETE /api/v1/sessions 204 5ms' },
  { level: 'info', msg: 'PATCH /api/v1/projects/acme 200 11ms' },
];

const LOG_LEVEL_COLORS: Record<string, { text: string; label: string }> = {
  info: { text: '#60a5fa', label: 'INFO ' },
  warn: { text: '#fbbf24', label: 'WARN ' },
  error: { text: '#f87171', label: 'ERROR' },
  debug: { text: '#a1a1b5', label: 'DEBUG' },
};

type LogLevel = 'all' | 'info' | 'warn' | 'error' | 'debug';
type LogLine = { id: string; time: string; level: string; msg: string };

const MAX_LINES = 120;
const INITIAL_COUNT = 14;

function nowTime() {
  const d = new Date();
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}:${String(d.getSeconds()).padStart(2, '0')}.${String(d.getMilliseconds()).padStart(3, '0')}`;
}

// ─── Component ───────────────────────────────────────────────────────────────

interface LogsSectionProps {
  project: Project;
}

export function LogsSection({ project }: LogsSectionProps) {
  const [filter, setFilter] = useState<LogLevel>('all');
  const [lines, setLines] = useState<LogLine[]>(() =>
    LOG_POOL.slice(0, INITIAL_COUNT).map((l, i) => ({ ...l, id: String(i), time: nowTime() })),
  );
  const poolIndex = useRef(INITIAL_COUNT % LOG_POOL.length);
  const counter = useRef(INITIAL_COUNT);
  const scrollRef = useRef<ScrollView>(null);

  // Stream a new log line every 1.4s
  useEffect(() => {
    const timer = setInterval(() => {
      const entry = LOG_POOL[poolIndex.current % LOG_POOL.length];
      poolIndex.current += 1;
      counter.current += 1;
      const newLine: LogLine = { ...entry, id: String(counter.current), time: nowTime() };
      setLines(prev => {
        const next = [...prev, newLine];
        return next.length > MAX_LINES ? next.slice(next.length - MAX_LINES) : next;
      });
    }, 1400);
    return () => clearInterval(timer);
  }, []);

  // Auto-scroll to bottom
  useEffect(() => {
    scrollRef.current?.scrollToEnd({ animated: true });
  }, [lines]);

  const filtered = filter === 'all' ? lines : lines.filter(l => l.level === filter);
  const filterBtns: LogLevel[] = ['all', 'info', 'warn', 'error', 'debug'];

  return (
    <View className="gap-3">
      {/* Filter row */}
      <ScrollView horizontal showsHorizontalScrollIndicator={false}>
        <View className="flex-row gap-1.5">
          {filterBtns.map(lvl => {
            const active = filter === lvl;
            const c =
              lvl === 'all' ? '#6366f1' : (LOG_LEVEL_COLORS[lvl]?.text ?? '#6366f1');
            return (
              <TouchableOpacity
                key={lvl}
                onPress={() => setFilter(lvl)}
                className={cn(
                  'px-2.5 py-1.5 rounded-md border',
                  active ? 'border-current' : 'border-neutral-200 dark:border-neutral-700'
                )}
                style={{
                  borderColor: active ? c : undefined,
                  backgroundColor: active ? `${c}18` : 'transparent',
                }}
              >
                <Text 
                  className="text-xs font-semibold"
                  style={{ color: active ? c : '#999' }}
                >
                  {lvl.toUpperCase()}
                </Text>
              </TouchableOpacity>
            );
          })}
        </View>
      </ScrollView>

      {/* Terminal */}
      <View className="bg-black border border-neutral-800 rounded-2xl overflow-hidden">
        <View className="flex-row items-center px-3.5 py-2.5 border-b border-neutral-800">
          <View className="flex-row gap-1.5 mr-2.5">
            <View className="w-2.5 h-2.5 rounded-full" style={{ backgroundColor: '#ef4444' }} />
            <View className="w-2.5 h-2.5 rounded-full" style={{ backgroundColor: '#fbbf24' }} />
            <View className="w-2.5 h-2.5 rounded-full" style={{ backgroundColor: '#22c55e' }} />
          </View>
          <Text className="flex-1 text-gray-600 text-xs">{project.name} — live logs</Text>
          <View className="flex-row items-center gap-1">
            <View className="w-1.5 h-1.5 rounded-full" style={{ backgroundColor: '#22c55e' }} />
            <Text className="text-xs font-bold" style={{ color: '#22c55e' }}>LIVE</Text>
          </View>
        </View>

        <ScrollView
          ref={scrollRef}
          className="max-h-[420px] px-3.5 py-2.5"
          showsVerticalScrollIndicator={false}
        >
          {filtered.map(line => {
            const lvl = LOG_LEVEL_COLORS[line.level] ?? LOG_LEVEL_COLORS.info;
            return (
              <View key={line.id} className="flex-row gap-2 py-0.75 items-start">
                <Text className="text-xs font-mono" style={{ color: '#4b5563', width: 84 }}>
                  {line.time}
                </Text>
                <Text 
                  className="text-xs font-mono font-semibold" 
                  style={{ color: lvl.text, width: 42 }}
                >
                  {lvl.label}
                </Text>
                <Text 
                  className="text-xs font-mono flex-1" 
                  numberOfLines={2}
                  style={{ color: '#d1d5db' }}
                >
                  {line.msg}
                </Text>
              </View>
            );
          })}
        </ScrollView>
      </View>
    </View>
  );
}

// ─── Styles ──────────────────────────────────────────────────────────────────
// All styling is now handled via Tailwind CSS classes
