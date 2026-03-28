import { useEffect, useState } from "react"
import {
  buildControlPlaneViewModel,
  fetchControlPlaneStatus,
  subscribeToControlPlaneStatus,
  type ControlPlaneStatusSnapshot,
} from "@/lib/api"
import type { Deployment, Project } from "@/routes/projects/data"

interface ControlPlaneDataState {
  snapshot: ControlPlaneStatusSnapshot | null
  projects: Project[]
  deployments: Deployment[]
  error: string | null
  isLoading: boolean
}

export function useControlPlaneData() {
  const [state, setState] = useState<ControlPlaneDataState>({
    snapshot: null,
    projects: [],
    deployments: [],
    error: null,
    isLoading: true,
  })

  useEffect(() => {
    const unsubscribe = subscribeToControlPlaneStatus(
      (snapshot) => {
        const viewModel = buildControlPlaneViewModel(snapshot)
        setState({
          snapshot: viewModel.snapshot,
          projects: viewModel.projects,
          deployments: viewModel.deployments,
          error: null,
          isLoading: false,
        })
      },
      (connection) => {
        setState((current) => ({
          ...current,
          error: connection.error,
          isLoading: current.snapshot === null && !connection.error,
        }))
      },
    )

    void fetchControlPlaneStatus()
      .then((snapshot) => {
        const viewModel = buildControlPlaneViewModel(snapshot)
        setState({
          snapshot: viewModel.snapshot,
          projects: viewModel.projects,
          deployments: viewModel.deployments,
          error: null,
          isLoading: false,
        })
      })
      .catch((error) => {
        setState((current) => ({
          ...current,
          error:
            error instanceof Error
              ? error.message
              : "Failed to request control plane status.",
          isLoading: false,
        }))
      })

    return unsubscribe
  }, [])

  return {
    ...state,
    refetch: () => fetchControlPlaneStatus().then(() => undefined),
  }
}
