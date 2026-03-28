export type ProjectType =
  | "project"
  | "website"
  | "game-server"
  | "api"
  | "worker"
  | "cron"
export type ProjectStatus = "running" | "stopped" | "deploying" | "error"
export type DeploymentStatus = "success" | "failed" | "in-progress"

export interface ProjectAppContainer {
  id: string
  status: string
  workerId?: string
  workerRegion?: string
  cpu: number
  memory: number
  uptime: number
  image?: string
  lastError?: string
  lastUpdatedAt?: string
  retryCount: number
}

export interface ProjectApp {
  id: string
  name: string
  description: string
  type: ProjectType
  status: ProjectStatus
  region: string
  url?: string
  uptime: string
  cpu: number
  memory: number
  instances: number
  desiredInstances: number
  image?: string
  kind?: string
  ports?: number[]
  lastError?: string
  containers: ProjectAppContainer[]
}

export interface Project {
  id: string
  name: string
  description: string
  type: ProjectType
  status: ProjectStatus
  region: string
  url?: string
  uptime: string
  lastDeployedAt?: string
  lastDeployedBy: string
  cpu: number
  memory: number
  instances: number
  desiredInstances?: number
  image?: string
  kind?: string
  ports?: number[]
  lastError?: string
  appCount?: number
  apps?: ProjectApp[]
}

export interface Deployment {
  id: string
  projectId: string
  commit: string
  branch: string
  message: string
  status: DeploymentStatus
  createdAt?: string
  duration: string
  deployedBy: string
}
