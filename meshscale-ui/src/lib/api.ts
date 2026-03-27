const DEFAULT_CONTROL_PLANE_URL = "http://localhost:8080"

export const CONTROL_PLANE_URL =
  import.meta.env.VITE_CONTROL_PLANE_URL ?? DEFAULT_CONTROL_PLANE_URL

export async function deployInfrastructure(source: string): Promise<void> {
  const res = await fetch(`${CONTROL_PLANE_URL}/api/v1/deploy`, {
    method: "POST",
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
    },
    body: source,
  })

  if (!res.ok) {
    const text = await res.text().catch(() => "")
    throw new Error(
      `Deploy failed with status ${res.status}${
        text ? `: ${text.slice(0, 200)}` : ""
      }`,
    )
  }
}

