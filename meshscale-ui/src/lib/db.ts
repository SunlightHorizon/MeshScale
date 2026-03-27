import Dexie, { type Table } from "dexie"
import type { Project, Deployment } from "@/routes/projects/data"

export class MeshScaleDB extends Dexie {
  projects!: Table<Project, string>
  deployments!: Table<Deployment, string>

  constructor() {
    super("meshscale")
    this.version(1).stores({
      projects: "id, name, type, status, region",
      deployments: "id, projectId, status",
    })
  }
}

export const db = new MeshScaleDB()

// ---------------------------------------------------------------------------
// Seed with demo data on first load
// ---------------------------------------------------------------------------

const seedProjects: Project[] = [
  {
    id: "acme-website",
    name: "Acme Website",
    description: "Main marketing and landing page for Acme Corp",
    type: "website",
    status: "running",
    region: "us-east-1",
    url: "https://acme.meshscale.io",
    uptime: "99.98%",
    lastDeployed: "2 hours ago",
    lastDeployedBy: "Eddie Lake",
    cpu: 12,
    memory: 34,
    instances: 3,
  },
  {
    id: "survival-craft",
    name: "SurvivalCraft Server",
    description: "Minecraft-like survival game server with 50 player capacity",
    type: "game-server",
    status: "running",
    region: "eu-west-1",
    uptime: "99.81%",
    lastDeployed: "5 days ago",
    lastDeployedBy: "Eddie Lake",
    cpu: 67,
    memory: 72,
    instances: 1,
  },
  {
    id: "payments-api",
    name: "Payments API",
    description: "REST API handling payment processing and billing",
    type: "api",
    status: "running",
    region: "us-west-2",
    url: "https://api.payments.meshscale.io",
    uptime: "100%",
    lastDeployed: "3 days ago",
    lastDeployedBy: "Jamik Tashpulatov",
    cpu: 23,
    memory: 41,
    instances: 5,
  },
  {
    id: "email-worker",
    name: "Email Worker",
    description: "Background worker for transactional email queue processing",
    type: "worker",
    status: "stopped",
    region: "us-east-1",
    uptime: "87.3%",
    lastDeployed: "1 week ago",
    lastDeployedBy: "Eddie Lake",
    cpu: 0,
    memory: 0,
    instances: 0,
  },
  {
    id: "battle-arena",
    name: "Battle Arena",
    description: "Competitive 5v5 multiplayer arena game server",
    type: "game-server",
    status: "deploying",
    region: "ap-southeast-1",
    uptime: "95.2%",
    lastDeployed: "Just now",
    lastDeployedBy: "Eddie Lake",
    cpu: 0,
    memory: 0,
    instances: 0,
  },
  {
    id: "analytics-sync",
    name: "Analytics Sync",
    description: "Hourly cron job to sync analytics events to data warehouse",
    type: "cron",
    status: "running",
    region: "us-east-1",
    uptime: "99.4%",
    lastDeployed: "2 weeks ago",
    lastDeployedBy: "Jamik Tashpulatov",
    cpu: 3,
    memory: 8,
    instances: 1,
  },
]

const seedDeployments: Deployment[] = [
  // acme-website
  { id: "aw-d1", projectId: "acme-website", commit: "a4f3b2c", branch: "main", message: "Update hero section and CTA copy", status: "success", createdAt: "2 hours ago", duration: "1m 24s", deployedBy: "Eddie Lake" },
  { id: "aw-d2", projectId: "acme-website", commit: "9e1d8fa", branch: "main", message: "Fix mobile navigation layout", status: "success", createdAt: "1 day ago", duration: "1m 12s", deployedBy: "Eddie Lake" },
  { id: "aw-d3", projectId: "acme-website", commit: "3c7a9e2", branch: "feat/new-contact-form", message: "Add contact form with validation", status: "failed", createdAt: "2 days ago", duration: "2m 05s", deployedBy: "Jamik Tashpulatov" },
  { id: "aw-d4", projectId: "acme-website", commit: "1b9f4d7", branch: "main", message: "Add testimonials section", status: "success", createdAt: "4 days ago", duration: "1m 08s", deployedBy: "Jamik Tashpulatov" },
  // survival-craft
  { id: "sc-d1", projectId: "survival-craft", commit: "f8c2d1a", branch: "main", message: "Update server config and increase player cap", status: "success", createdAt: "5 days ago", duration: "3m 10s", deployedBy: "Eddie Lake" },
  { id: "sc-d2", projectId: "survival-craft", commit: "c3a7f9b", branch: "main", message: "Add new biome generation plugin", status: "success", createdAt: "2 weeks ago", duration: "4m 32s", deployedBy: "Eddie Lake" },
  // payments-api
  { id: "pa-d1", projectId: "payments-api", commit: "b5e4c9d", branch: "main", message: "Add Stripe webhook handler", status: "success", createdAt: "3 days ago", duration: "45s", deployedBy: "Jamik Tashpulatov" },
  { id: "pa-d2", projectId: "payments-api", commit: "2a8f7e1", branch: "main", message: "Rate limiting and DDoS protection improvements", status: "success", createdAt: "6 days ago", duration: "38s", deployedBy: "Jamik Tashpulatov" },
  { id: "pa-d3", projectId: "payments-api", commit: "7d1c4e8", branch: "fix/refund-flow", message: "Fix refund flow edge case", status: "success", createdAt: "1 week ago", duration: "41s", deployedBy: "Eddie Lake" },
  // email-worker
  { id: "ew-d1", projectId: "email-worker", commit: "7d3a2c5", branch: "main", message: "Migrate to Resend email provider", status: "success", createdAt: "1 week ago", duration: "52s", deployedBy: "Eddie Lake" },
  // battle-arena
  { id: "ba-d1", projectId: "battle-arena", commit: "c9f1b3e", branch: "main", message: "Season 2 game mode update with new maps", status: "in-progress", createdAt: "Just now", duration: "-", deployedBy: "Eddie Lake" },
  { id: "ba-d2", projectId: "battle-arena", commit: "4e7b2a9", branch: "main", message: "Matchmaking algorithm improvements", status: "success", createdAt: "3 days ago", duration: "5m 18s", deployedBy: "Jamik Tashpulatov" },
  // analytics-sync
  { id: "as-d1", projectId: "analytics-sync", commit: "e2d9c4a", branch: "main", message: "Add new funnel metrics tracking", status: "success", createdAt: "2 weeks ago", duration: "28s", deployedBy: "Jamik Tashpulatov" },
]

async function seed() {
  const count = await db.projects.count()
  if (count === 0) {
    await db.projects.bulkAdd(seedProjects)
    await db.deployments.bulkAdd(seedDeployments)
  }
}

// Only seed in the browser (IndexedDB is not available server-side)
if (typeof window !== "undefined") {
  seed().catch(console.error)
}
