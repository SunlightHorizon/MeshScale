// ─── Global Store ────────────────────────────────────────────────────────────
// React Context store for projects and deployments.
// Provides addProject, addDeployment, updateProject mutations.

import React, { createContext, useContext, useState, useMemo, useCallback } from 'react';
import { Project, Deployment } from './types';
import { SEED_PROJECTS, SEED_DEPLOYMENTS } from './seed-data';

// ─── Types ───────────────────────────────────────────────────────────────────

interface StoreState {
  projects: Project[];
  deployments: Deployment[];
  addProject: (project: Project) => void;
  addDeployment: (deployment: Deployment) => void;
  updateProject: (id: string, updates: Partial<Project>) => void;
}

// ─── Context ─────────────────────────────────────────────────────────────────

const StoreContext = createContext<StoreState | null>(null);

// ─── Provider ────────────────────────────────────────────────────────────────

export function StoreProvider({ children }: { children: React.ReactNode }) {
  const [projects, setProjects] = useState<Project[]>(SEED_PROJECTS);
  const [deployments, setDeployments] = useState<Deployment[]>(SEED_DEPLOYMENTS);

  const addProject = useCallback((project: Project) => {
    setProjects(prev => [project, ...prev]);
  }, []);

  const addDeployment = useCallback((deployment: Deployment) => {
    setDeployments(prev => [deployment, ...prev]);
  }, []);

  const updateProject = useCallback((id: string, updates: Partial<Project>) => {
    setProjects(prev => prev.map(p => (p.id === id ? { ...p, ...updates } : p)));
  }, []);

  const value = useMemo(
    () => ({ projects, deployments, addProject, addDeployment, updateProject }),
    [projects, deployments, addProject, addDeployment, updateProject],
  );

  return (
    <StoreContext.Provider value={value}>
      {children}
    </StoreContext.Provider>
  );
}

// ─── Hook ────────────────────────────────────────────────────────────────────

export function useStore() {
  const ctx = useContext(StoreContext);
  if (!ctx) throw new Error('useStore must be used within StoreProvider');
  return ctx;
}
