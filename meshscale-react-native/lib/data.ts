// ─── Re-export for backward compatibility ───────────────────────────────────
// New code should import directly from @/lib/types and @/lib/seed-data.

export type { ProjectType, ProjectStatus, DeploymentStatus, Project, Deployment } from './types';
export { SEED_PROJECTS, SEED_DEPLOYMENTS } from './seed-data';
