import type {
  Deployment,
  ProjectApp,
  ProjectAppContainer,
  Project,
  ProjectStatus,
  ProjectType,
} from "@/routes/projects/data"

const DEFAULT_CONTROL_PLANE_HOST =
  typeof window !== "undefined" && window.location.hostname
    ? window.location.hostname
    : "localhost"
const DEFAULT_CONTROL_PLANE_URLS = [
  `http://${DEFAULT_CONTROL_PLANE_HOST}:8080`,
  `http://${DEFAULT_CONTROL_PLANE_HOST}:8082`,
]
const DEFAULT_CONTROL_PLANE_URL = DEFAULT_CONTROL_PLANE_URLS[0]

export const CONTROL_PLANE_URL =
  import.meta.env.VITE_CONTROL_PLANE_URL ?? DEFAULT_CONTROL_PLANE_URL
export const CONTROL_PLANE_URLS = normalizeControlPlaneURLList([
  ...(import.meta.env.VITE_CONTROL_PLANE_URLS
    ? String(import.meta.env.VITE_CONTROL_PLANE_URLS)
        .split(",")
        .map((value) => value.trim())
        .filter(Boolean)
    : []),
  CONTROL_PLANE_URL,
  ...DEFAULT_CONTROL_PLANE_URLS,
])

export type ControlPlaneResourceKind =
  | "database"
  | "cache"
  | "httpService"
  | "webService"
  | "meshscaleDashboard"
  | "netbirdDashboard"
  | "backgroundWorker"
  | "staticSite"
  | "objectStorage"
  | "messageQueue"

export interface ControlPlaneDesiredResource {
  name: string
  kind: ControlPlaneResourceKind
  cpu: number
  memoryGB: number
  storageGB?: number | null
  replicas: number
  image?: string | null
  env: Record<string, string>
  ports: number[]
  latencySensitivity: "high" | "medium" | "low"
}

export interface ControlPlaneRuntimeOutput {
  key: string
  value: string
  updatedAt: string
}

export interface ControlPlanePeer {
  id: string
  region: string
  apiURL: string
  netbirdIP: string
  lastSeenAt: string
  status: string
}

export interface ControlPlaneSharedProject {
  id: string
  domain?: string | null
  revision: number
  primaryRegion?: string | null
  shardIds: string[]
  lastDeployedAt?: string | null
  lastUpdatedAt: string
}

export interface ControlPlaneProjectShard {
  projectId: string
  shardId: string
  region: string
  controlPlaneIds: string[]
  workerIds: string[]
  desiredResourceNames: string[]
  containerIds: string[]
  lastUpdatedAt: string
}

export interface ControlPlanePlannedContainer {
  id: string
  resourceName: string
  replicaIndex: number
  targetWorkerId?: string | null
  kind: ControlPlaneResourceKind
  image?: string | null
  cpu: number
  memoryGB: number
  ports: number[]
  env: Record<string, string>
  workerTypeHint: "general" | "databaseHeavy" | "compute" | "controlPlane"
}

export interface ControlPlaneWorker {
  id: string
  type: "general" | "databaseHeavy" | "compute" | "controlPlane"
  region: string
  netbirdIP: string
  lastSeenAt: string
  status: string
}

export interface ControlPlaneWorkerHealth {
  workerId: string
  runningContainers: number
  totalContainers: number
  reportedAt: string
}

export interface ControlPlaneWorkerContainerStatus {
  id: string
  status: string
  cpu: number
  memory: number
  uptime: number
  image?: string | null
  lastError?: string | null
  lastUpdatedAt?: string | null
  retryCount: number
}

export interface ControlPlaneWorkerContainers {
  workerId: string
  containers: ControlPlaneWorkerContainerStatus[]
}

export interface ControlPlaneAssignment {
  workerId: string
  containerId: string
  image?: string | null
  assignedAt: string
}

export interface ControlPlaneDeploymentPlan {
  generatedAt: string
  resources: ControlPlaneDesiredResource[]
  containers: ControlPlanePlannedContainer[]
}

export interface ControlPlaneStatusSnapshot {
  domain?: string | null
  lastDeployedAt?: string | null
  leaderControlPlaneID?: string | null
  controlPlanes: ControlPlanePeer[]
  projects?: ControlPlaneSharedProject[]
  projectShards?: ControlPlaneProjectShard[]
  desiredResources: ControlPlaneDesiredResource[]
  runtimeOutputs?: ControlPlaneRuntimeOutput[]
  workers: ControlPlaneWorker[]
  workerHealth: ControlPlaneWorkerHealth[]
  workerContainers: ControlPlaneWorkerContainers[]
  currentPlan?: ControlPlaneDeploymentPlan | null
  assignments: ControlPlaneAssignment[]
}

export interface DeploymentSubmission {
  domain?: string
  resources: ControlPlaneDesiredResource[]
}

export interface ControlPlaneViewModel {
  snapshot: ControlPlaneStatusSnapshot
  projects: Project[]
  deployments: Deployment[]
}

interface ControlPlaneSocketRequest {
  type: "request-status" | "deploy-manifest" | "deploy-source"
  id?: string
  payload?: DeploymentSubmission
  source?: string
}

interface ControlPlaneSocketResponse {
  type: "status-snapshot" | "command-result" | "error"
  id?: string
  success?: boolean
  error?: string
  snapshot?: ControlPlaneStatusSnapshot
}

interface SocketConnectionState {
  connected: boolean
  error: string | null
}

type SnapshotListener = (snapshot: ControlPlaneStatusSnapshot) => void
type ConnectionListener = (state: SocketConnectionState) => void

class ControlPlaneSocketClient {
  private socket: WebSocket | null = null
  private connectionPromise: Promise<void> | null = null
  private snapshotListeners = new Set<SnapshotListener>()
  private connectionListeners = new Set<ConnectionListener>()
  private pendingCommands = new Map<
    string,
    {
      resolve: () => void
      reject: (error: Error) => void
    }
  >()
  private reconnectTimer: number | null = null
  private latestSnapshot: ControlPlaneStatusSnapshot | null = null
  private lastError: string | null = null
  private candidateBaseURLs = [...CONTROL_PLANE_URLS]
  private activeBaseURL: string | null = null

  subscribe(
    onSnapshot: SnapshotListener,
    onConnectionChange?: ConnectionListener,
  ) {
    this.snapshotListeners.add(onSnapshot)
    if (onConnectionChange) {
      this.connectionListeners.add(onConnectionChange)
      onConnectionChange({
        connected: this.socket?.readyState === WebSocket.OPEN,
        error: this.lastError,
      })
    }

    if (this.latestSnapshot) {
      onSnapshot(this.latestSnapshot)
    }

    void this.ensureConnected()

    return () => {
      this.snapshotListeners.delete(onSnapshot)
      if (onConnectionChange) {
        this.connectionListeners.delete(onConnectionChange)
      }
    }
  }

  async requestStatus() {
    await this.send({
      type: "request-status",
    })
  }

  async fetchSnapshotNow(timeoutMs = 1_500) {
    if (this.latestSnapshot && this.socket?.readyState === WebSocket.OPEN) {
      return this.latestSnapshot
    }

    const candidates = this.prioritizedCandidateBaseURLs()
    let lastError: Error | null = null

    for (const candidate of candidates) {
      try {
        const snapshot = await requestSnapshotOverWebSocket(candidate, timeoutMs)
        this.activeBaseURL = candidate
        this.receiveSnapshot(snapshot)
        return snapshot
      } catch (error) {
        lastError =
          error instanceof Error
            ? error
            : new Error(`Failed to fetch status snapshot from ${candidate}.`)
      }
    }

    throw (
      lastError ??
      new Error("Failed to fetch a control plane status snapshot over websockets.")
    )
  }

  async deployManifest(submission: DeploymentSubmission) {
    await this.send(
      {
        type: "deploy-manifest",
        payload: submission,
      },
      true,
    )
  }

  async deploySource(source: string) {
    await this.send(
      {
        type: "deploy-source",
        source,
      },
      true,
    )
  }

  private async send(
    message: ControlPlaneSocketRequest,
    expectsResult = false,
  ) {
    await this.ensureConnected()

    if (!this.socket || this.socket.readyState !== WebSocket.OPEN) {
      throw new Error("Control plane websocket is not connected.")
    }

    const request = expectsResult
      ? {
          ...message,
          id: crypto.randomUUID(),
        }
      : message

    this.socket.send(JSON.stringify(request))

    if (!expectsResult || !request.id) {
      return
    }

    await new Promise<void>((resolve, reject) => {
      this.pendingCommands.set(request.id!, { resolve, reject })
    })
  }

  private async ensureConnected() {
    if (this.socket?.readyState === WebSocket.OPEN) {
      return
    }

    if (this.connectionPromise) {
      return this.connectionPromise
    }

    const candidates = this.prioritizedCandidateBaseURLs()
    if (candidates.length === 0) {
      throw new Error("No control plane URLs are configured.")
    }

    this.connectionPromise = this.connectToCandidateList(candidates)

    return this.connectionPromise
  }

  private connectToCandidateList(candidates: string[]) {
    return new Promise<void>((resolve, reject) => {
      const tryCandidate = (index: number, errors: string[]) => {
        if (index >= candidates.length) {
          this.connectionPromise = null
          this.socket = null
          this.lastError =
            errors[errors.length - 1] ??
            "Failed to open the control plane websocket."
          this.notifyConnectionListeners()
          reject(new Error(this.lastError))
          this.scheduleReconnect()
          return
        }

        const candidate = candidates[index]
        const socket = new WebSocket(`${toWebSocketURL(candidate)}/ws/control-plane`)
        let opened = false
        let receivedInitialSnapshot = false
        let handshakeTimer: number | null = null

        this.socket = socket

        socket.onopen = () => {
          opened = true
          this.activeBaseURL = candidate
          this.lastError = null
          this.connectionPromise = null
          this.notifyConnectionListeners()
          socket.send(
            JSON.stringify({
              type: "request-status",
            } satisfies ControlPlaneSocketRequest),
          )

          handshakeTimer = window.setTimeout(() => {
            if (receivedInitialSnapshot) {
              return
            }

            this.lastError = `Control plane ${candidate} opened a websocket but never sent a status snapshot.`
            this.notifyConnectionListeners()
            socket.close()
          }, 2_500)
        }

        socket.onmessage = (event) => {
          if (isStatusSnapshotMessage(event.data)) {
            receivedInitialSnapshot = true
            if (handshakeTimer) {
              window.clearTimeout(handshakeTimer)
              handshakeTimer = null
            }
            resolve()
          }
          this.handleMessage(event.data)
        }

        socket.onerror = () => {
          if (!opened) {
            return
          }
          this.lastError = `Lost connection to the control plane websocket at ${candidate}.`
          this.notifyConnectionListeners()
        }

        socket.onclose = () => {
          if (handshakeTimer) {
            window.clearTimeout(handshakeTimer)
            handshakeTimer = null
          }

          if (!opened) {
            tryCandidate(index + 1, [
              ...errors,
              `Failed to connect to control plane ${candidate}.`,
            ])
            return
          }

          if (opened && !receivedInitialSnapshot) {
            this.connectionPromise = null
            this.socket = null
            this.activeBaseURL = null

            tryCandidate(index + 1, [
              ...errors,
              this.lastError ??
                `Control plane ${candidate} did not send an initial status snapshot.`,
            ])
            return
          }

          this.connectionPromise = null
          this.socket = null
          this.activeBaseURL = null

          this.rejectPendingCommands(
            new Error("Control plane websocket connection closed."),
          )

          this.lastError = `Control plane websocket disconnected from ${candidate}.`
          this.notifyConnectionListeners()
          this.scheduleReconnect()
        }
      }

      tryCandidate(0, [])
    })
  }

  private handleMessage(rawMessage: unknown) {
    if (typeof rawMessage !== "string") {
      return
    }

    let parsed: ControlPlaneSocketResponse
    try {
      parsed = JSON.parse(rawMessage) as ControlPlaneSocketResponse
    } catch {
      this.lastError = "Received malformed websocket data from the control plane."
      this.notifyConnectionListeners()
      return
    }

    if (parsed.type === "status-snapshot" && parsed.snapshot) {
      this.receiveSnapshot(parsed.snapshot)
      return
    }

    if (parsed.type === "command-result" && parsed.id) {
      const pending = this.pendingCommands.get(parsed.id)
      if (!pending) {
        return
      }

      this.pendingCommands.delete(parsed.id)
      if (parsed.success) {
        pending.resolve()
      } else {
        pending.reject(new Error(parsed.error ?? "Command failed."))
      }
      return
    }

    if (parsed.type === "error") {
      this.lastError = parsed.error ?? "Control plane websocket reported an error."
      this.notifyConnectionListeners()
    }
  }

  private notifyConnectionListeners() {
    const state = {
      connected: this.socket?.readyState === WebSocket.OPEN,
      error: this.lastError,
    } satisfies SocketConnectionState

    for (const listener of this.connectionListeners) {
      listener(state)
    }
  }

  private rejectPendingCommands(error: Error) {
    for (const pending of this.pendingCommands.values()) {
      pending.reject(error)
    }
    this.pendingCommands.clear()
  }

  private replaceCandidateBaseURLs(snapshot: ControlPlaneStatusSnapshot) {
    const leaderId = snapshot.leaderControlPlaneID ?? null
    const discovered = freshControlPlanePeers(snapshot.controlPlanes ?? []).sort((left, right) => {
      if (leaderId) {
        if (left.id === leaderId && right.id !== leaderId) {
          return -1
        }
        if (right.id === leaderId && left.id !== leaderId) {
          return 1
        }
      }
      return left.id.localeCompare(right.id)
    })

    this.candidateBaseURLs = normalizeControlPlaneURLList([
      ...discovered.map((controlPlane) => controlPlane.apiURL),
      ...CONTROL_PLANE_URLS,
    ])
  }

  private prioritizedCandidateBaseURLs() {
    if (!this.activeBaseURL) {
      return [...this.candidateBaseURLs]
    }

    return normalizeControlPlaneURLList([
      this.activeBaseURL,
      ...this.candidateBaseURLs,
    ])
  }

  private scheduleReconnect() {
    if (this.reconnectTimer) {
      window.clearTimeout(this.reconnectTimer)
    }

    this.reconnectTimer = window.setTimeout(() => {
      if (
        this.snapshotListeners.size > 0 ||
        this.connectionListeners.size > 0 ||
        this.pendingCommands.size > 0
      ) {
        void this.ensureConnected()
      }
    }, 1_000)
  }

  private receiveSnapshot(snapshot: ControlPlaneStatusSnapshot) {
    this.latestSnapshot = snapshot
    this.replaceCandidateBaseURLs(snapshot)
    this.lastError = null
    this.notifyConnectionListeners()
    for (const listener of this.snapshotListeners) {
      listener(snapshot)
    }
  }
}

const controlPlaneSocketClient = new ControlPlaneSocketClient()

export function subscribeToControlPlaneStatus(
  onSnapshot: SnapshotListener,
  onConnectionChange?: ConnectionListener,
) {
  return controlPlaneSocketClient.subscribe(onSnapshot, onConnectionChange)
}

export async function fetchControlPlaneStatus(): Promise<ControlPlaneStatusSnapshot> {
  return controlPlaneSocketClient.fetchSnapshotNow()
}

export async function requestControlPlaneStatus() {
  await controlPlaneSocketClient.requestStatus()
}

export async function deployInfrastructure(source: string): Promise<void> {
  await controlPlaneSocketClient.deploySource(source)
}

export async function deployManifest(submission: DeploymentSubmission): Promise<void> {
  await controlPlaneSocketClient.deployManifest(submission)
}

export function buildControlPlaneViewModel(
  snapshot: ControlPlaneStatusSnapshot,
): ControlPlaneViewModel {
  const freshControlPlanes = freshControlPlanePeers(snapshot.controlPlanes ?? [])
  const sharedProject = [...(snapshot.projects ?? [])].sort((left, right) =>
    left.id.localeCompare(right.id),
  )[0]
  const sortedDesiredResources = [...snapshot.desiredResources].sort((left, right) =>
    left.name.localeCompare(right.name),
  )
  const workersById = new Map(snapshot.workers.map((worker) => [worker.id, worker]))
  const containerStatusesById = new Map<
    string,
    ControlPlaneWorkerContainerStatus & {
      workerId: string
      workerRegion?: string
    }
  >()

  for (const workerContainers of snapshot.workerContainers) {
    for (const container of workerContainers.containers) {
      containerStatusesById.set(container.id, {
        ...container,
        workerId: workerContainers.workerId,
        workerRegion: workersById.get(workerContainers.workerId)?.region,
      })
    }
  }

  const assignmentsByContainerId = new Map(
    snapshot.assignments.map((assignment) => [assignment.containerId, assignment]),
  )

  const assignmentsByResource = new Map<string, ControlPlaneAssignment[]>()
  for (const assignment of snapshot.assignments) {
    const resourceName = inferResourceName(
      assignment.containerId,
      snapshot.currentPlan?.containers,
    )
    assignmentsByResource.set(resourceName, [
      ...(assignmentsByResource.get(resourceName) ?? []),
      assignment,
    ])
  }

  const deployedAt =
    sharedProject?.lastDeployedAt ??
    snapshot.lastDeployedAt ??
    snapshot.currentPlan?.generatedAt
  const deployedAtDate = deployedAt ? new Date(deployedAt) : null

  const apps = sortedDesiredResources.map((resource) => {
    const assignments = assignmentsByResource.get(resource.name) ?? []
    const plannedContainers = (
      snapshot.currentPlan?.containers.filter(
        (container) => container.resourceName === resource.name,
      ) ?? placeholderContainersForResource(resource)
    ).sort((left, right) => left.id.localeCompare(right.id))
    const reservedCpu = plannedContainers.reduce(
      (sum, container) => sum + container.cpu,
      0,
    )
    const reservedMemory = plannedContainers.reduce(
      (sum, container) => sum + container.memoryGB,
      0,
    )
    const desiredInstances = plannedContainers.length

    const containers = plannedContainers.map((container) => {
      const status = containerStatusesById.get(container.id)
      const assignment = assignmentsByContainerId.get(container.id)
      const assignedWorker = assignment
        ? workersById.get(assignment.workerId)
        : undefined

      return {
        id: container.id,
        status: status?.status ?? (assignment ? "assigned" : "pending"),
        workerId: status?.workerId ?? assignment?.workerId,
        workerRegion: status?.workerRegion ?? assignedWorker?.region,
        cpu: status?.cpu ?? 0,
        memory: status?.memory ?? 0,
        uptime: status?.uptime ?? 0,
        image: status?.image ?? container.image ?? undefined,
        lastError: status?.lastError ?? undefined,
        lastUpdatedAt: status?.lastUpdatedAt ?? undefined,
        retryCount: status?.retryCount ?? 0,
      } satisfies ProjectAppContainer
    })

    const runningInstances = containers.filter(
      (container) => container.status === "running",
    ).length
    const hasFailedContainer = containers.some(
      (container) => container.status === "failed",
    )
    const hasProgress = containers.some(
      (container) =>
        container.status !== "pending" &&
        container.status !== "created",
    )

    const appStatus = deriveWorkloadStatus(
      hasFailedContainer,
      runningInstances,
      desiredInstances,
      hasProgress || assignments.length > 0,
    )

    const regions = Array.from(
      new Set(
        containers
          .map((container) => container.workerRegion)
          .filter(Boolean) as string[],
      ),
    )

    return {
      id: resource.name,
      name: titleize(resource.name),
      description: describeResource(resource),
      type: projectTypeForResource(resource.kind),
      status: appStatus,
      region: regions[0] ?? "unassigned",
      url: primaryUrlForResource(resource, snapshot, freshControlPlanes),
      uptime:
        desiredInstances > 0
          ? `${runningInstances}/${desiredInstances} online`
          : "0/0 online",
      cpu: reservedCpu,
      memory: reservedMemory,
      instances: runningInstances,
      desiredInstances,
      image: resource.image ?? undefined,
      kind: resource.kind,
      ports: resource.ports,
      lastError:
        containers.find((container) => container.lastError)?.lastError,
      containers,
    } satisfies ProjectApp
  })

  const totalDesiredContainers = apps.reduce(
    (sum, app) => sum + app.desiredInstances,
    0,
  )
  const runningContainers = apps.reduce((sum, app) => sum + app.instances, 0)
  const appRegions = Array.from(
    new Set(apps.map((app) => app.region).filter((region) => region !== "unassigned")),
  )
  const hasAnyFailedApp = apps.some((app) => app.status === "error")
  const hasAnyProgress = apps.some(
    (app) => app.status === "deploying" || app.status === "running",
  )
  const projectStatus = deriveWorkloadStatus(
    hasAnyFailedApp,
    runningContainers,
    totalDesiredContainers,
    hasAnyProgress,
  )

  const shouldShowProject =
    apps.length > 0 ||
    Boolean(snapshot.domain) ||
    Boolean(snapshot.currentPlan) ||
    (snapshot.runtimeOutputs?.length ?? 0) > 0

  const projectId = sharedProject?.id ?? "swift-project"
  const projects = shouldShowProject
    ? [
        {
          id: projectId,
          name: sharedProject?.domain ?? snapshot.domain ?? "Deployed Swift App",
          description:
            apps.length > 0
              ? `${apps.length} app${apps.length === 1 ? "" : "s"} declared by the deployed Swift source`
              : "Swift source deployed to the MeshScale control plane",
          type: "project",
          status: projectStatus,
          region:
            appRegions.length > 1
              ? "multi-region"
              : sharedProject?.primaryRegion ?? appRegions[0] ?? "unassigned",
          url:
            sharedProject?.domain ?? snapshot.domain
              ? `http://${sharedProject?.domain ?? snapshot.domain}`
              : undefined,
          uptime: `${runningContainers}/${totalDesiredContainers} containers online`,
          lastDeployedAt: deployedAt ?? undefined,
          lastDeployedBy: "Control Plane",
          cpu: apps.reduce((sum, app) => sum + app.cpu, 0),
          memory: apps.reduce((sum, app) => sum + app.memory, 0),
          instances: runningContainers,
          desiredInstances: totalDesiredContainers,
          lastError: apps.find((app) => app.lastError)?.lastError,
          appCount: apps.length,
          apps,
        } satisfies Project,
      ].sort((left, right) => left.name.localeCompare(right.name))
    : []

  const deployments = projects.map((project) => ({
    id: `${project.id}-current`,
    projectId: project.id,
    commit: "control-plane",
    branch: "desired-state",
    message: `Apply desired state for ${project.name}`,
    status:
      project.status === "error"
        ? "failed"
        : project.status === "running"
          ? "success"
          : "in-progress",
    createdAt: deployedAt ?? undefined,
    duration: deployedAtDate ? "live" : "-",
    deployedBy: "Control Plane",
  } satisfies Deployment)).sort((left, right) =>
    left.projectId.localeCompare(right.projectId),
  )

  return { snapshot, projects, deployments }
}

function placeholderContainersForResource(resource: ControlPlaneDesiredResource) {
  const replicas = Math.max(resource.replicas, 1)
  return Array.from({ length: replicas }, (_, index) => ({
    id: replicas === 1 ? resource.name : `${resource.name}-${index}`,
    resourceName: resource.name,
    replicaIndex: index,
    kind: resource.kind,
    image: resource.image ?? null,
    cpu: resource.cpu,
    memoryGB: resource.memoryGB,
    ports: resource.ports,
    env: resource.env,
    workerTypeHint: "general" as const,
  }))
}

function deriveWorkloadStatus(
  hasFailure: boolean,
  runningInstances: number,
  desiredInstances: number,
  hasProgress: boolean,
): ProjectStatus {
  if (hasFailure) {
    return "error"
  }
  if (desiredInstances > 0 && runningInstances >= desiredInstances) {
    return "running"
  }
  if (hasProgress) {
    return "deploying"
  }
  return "stopped"
}

function inferResourceName(
  containerId: string,
  containers: ControlPlanePlannedContainer[] | undefined,
) {
  const explicitMatch = containers?.find((container) => container.id === containerId)
  if (explicitMatch) {
    return explicitMatch.resourceName
  }

  const replicaSuffix = containerId.match(/^(.*)-\d+$/)
  return replicaSuffix?.[1] ?? containerId
}

function projectTypeForResource(kind: ControlPlaneResourceKind): ProjectType {
  switch (kind) {
    case "webService":
    case "meshscaleDashboard":
    case "netbirdDashboard":
    case "staticSite":
      return "website"
    case "httpService":
      return "api"
    case "backgroundWorker":
    case "database":
    case "cache":
    case "objectStorage":
    case "messageQueue":
      return "worker"
  }
}

function describeResource(resource: ControlPlaneDesiredResource) {
  const kindLabel = resource.kind
    .replace(/([A-Z])/g, " $1")
    .trim()
    .toLowerCase()

  const image = resource.image ? ` using ${resource.image}` : ""
  const ports =
    resource.ports.length > 0 ? ` on ${resource.ports.join(", ")}` : ""

  return `${kindLabel} deployment${image}${ports}`.replace(/\s+/g, " ")
}

function primaryUrlForResource(
  resource: ControlPlaneDesiredResource,
  snapshot: ControlPlaneStatusSnapshot,
  controlPlanes: ControlPlanePeer[] = freshControlPlanePeers(snapshot.controlPlanes ?? []),
) {
  const port = resource.ports[0]
  const leaderControlPlane = [...controlPlanes]
    .sort((left, right) => {
      if (snapshot.leaderControlPlaneID) {
        if (left.id === snapshot.leaderControlPlaneID && right.id !== snapshot.leaderControlPlaneID) {
          return -1
        }
        if (right.id === snapshot.leaderControlPlaneID && left.id !== snapshot.leaderControlPlaneID) {
          return 1
        }
      }
      return left.id.localeCompare(right.id)
    })[0]
  const leaderHost = leaderControlPlane ? safeURLHost(leaderControlPlane.apiURL) : undefined

  switch (resource.kind) {
    case "webService":
    case "meshscaleDashboard":
    case "netbirdDashboard":
    case "staticSite":
      if (snapshot.domain) {
        return `http://${snapshot.domain}`
      }
      if (leaderHost && port) {
        return `http://${leaderHost}:${port}`
      }
      return port ? `http://localhost:${port}` : undefined
    case "httpService":
      if (leaderHost && port) {
        return `http://${leaderHost}:${port}`
      }
      return port ? `http://localhost:${port}` : undefined
    default:
      return undefined
  }
}

function safeURLHost(value: string) {
  try {
    return new URL(value).hostname
  } catch {
    return undefined
  }
}

function titleize(value: string) {
  return value
    .split("-")
    .filter(Boolean)
    .map((part) => part[0]?.toUpperCase() + part.slice(1))
    .join(" ")
}

function toWebSocketURL(baseURL: string) {
  const normalized = new URL(baseURL)
  normalized.protocol = normalized.protocol === "https:" ? "wss:" : "ws:"
  normalized.pathname = normalized.pathname.replace(/\/$/, "")
  return normalized.toString().replace(/\/$/, "")
}

function normalizeControlPlaneURLList(urls: string[]) {
  const unique = new Set<string>()

  for (const rawURL of urls) {
    if (!rawURL) {
      continue
    }

    try {
      const normalized = new URL(rawURL)
      normalized.pathname = normalized.pathname.replace(/\/$/, "")
      unique.add(normalized.toString().replace(/\/$/, ""))
    } catch {
      // Ignore malformed control plane URLs from local env or stale snapshots.
    }
  }

  return [...unique]
}

function freshControlPlanePeers(
  controlPlanes: ControlPlanePeer[],
  now = Date.now(),
) {
  return controlPlanes.filter((controlPlane) => {
    const lastSeenAt = Date.parse(controlPlane.lastSeenAt)
    if (Number.isNaN(lastSeenAt)) {
      return true
    }

    return now - lastSeenAt <= 30_000
  })
}

function isStatusSnapshotMessage(rawMessage: unknown) {
  if (typeof rawMessage !== "string") {
    return false
  }

  try {
    return Boolean(parseStatusSnapshotMessage(rawMessage))
  } catch {
    return false
  }
}

function parseStatusSnapshotMessage(rawMessage: string) {
  const parsed = JSON.parse(rawMessage) as ControlPlaneSocketResponse
  if (parsed.type !== "status-snapshot" || !parsed.snapshot) {
    return null
  }

  return parsed.snapshot
}

function requestSnapshotOverWebSocket(baseURL: string, timeoutMs: number) {
  return new Promise<ControlPlaneStatusSnapshot>((resolve, reject) => {
    const socket = new WebSocket(`${toWebSocketURL(baseURL)}/ws/control-plane`)
    let settled = false

    const finish = (
      callback: (value?: ControlPlaneStatusSnapshot | Error) => void,
      value?: ControlPlaneStatusSnapshot | Error,
    ) => {
      if (settled) {
        return
      }
      settled = true
      window.clearTimeout(timer)
      try {
        socket.close()
      } catch {
        // Ignore close errors on one-shot sockets.
      }
      callback(value)
    }

    const timer = window.setTimeout(() => {
      finish(
        (value) =>
          reject(
            value instanceof Error
              ? value
              : new Error(`Timed out waiting for a status snapshot from ${baseURL}.`),
          ),
        new Error(`Timed out waiting for a status snapshot from ${baseURL}.`),
      )
    }, timeoutMs)

    socket.onopen = () => {
      socket.send(
        JSON.stringify({
          type: "request-status",
        } satisfies ControlPlaneSocketRequest),
      )
    }

    socket.onmessage = (event) => {
      if (typeof event.data !== "string") {
        return
      }

      const snapshot = parseStatusSnapshotMessage(event.data)
      if (!snapshot) {
        return
      }

      finish((value) => resolve(value as ControlPlaneStatusSnapshot), snapshot)
    }

    socket.onerror = () => {
      finish(
        (value) =>
          reject(
            value instanceof Error
              ? value
              : new Error(`Failed to connect to control plane ${baseURL}.`),
          ),
        new Error(`Failed to connect to control plane ${baseURL}.`),
      )
    }

    socket.onclose = () => {
      if (settled) {
        return
      }

      finish(
        (value) =>
          reject(
            value instanceof Error
              ? value
              : new Error(`Control plane ${baseURL} closed before sending a snapshot.`),
          ),
        new Error(`Control plane ${baseURL} closed before sending a snapshot.`),
      )
    }
  })
}
