// ─── Domain Types ────────────────────────────────────────────────────────────
// Single source of truth for all data shapes used across the app.

export type ProjectType = 'website' | 'game-server' | 'api' | 'worker' | 'cron';

export type ProjectStatus = 'running' | 'stopped' | 'deploying' | 'error';

export type DeploymentStatus = 'success' | 'failed' | 'in-progress';

export interface Project {
  id: string;
  name: string;
  description: string;
  type: ProjectType;
  status: ProjectStatus;
  region: string;
  url?: string;
  uptime: string;
  lastDeployed: string;
  lastDeployedBy: string;
  cpu: number;
  memory: number;
  instances: number;
}

export interface Deployment {
  id: string;
  projectId: string;
  commit: string;
  branch: string;
  message: string;
  status: DeploymentStatus;
  createdAt: string;
  duration: string;
  deployedBy: string;
}
