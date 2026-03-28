import * as React from "react"
import { formatDistanceToNowStrict } from "date-fns"

const SECOND = 1_000

function formatRelativeTime(value?: string, fallback = "never") {
  if (!value) {
    return fallback
  }

  const date = new Date(value)
  if (Number.isNaN(date.getTime())) {
    return fallback
  }

  return formatDistanceToNowStrict(date, { addSuffix: true })
}

export function RelativeTime({
  value,
  fallback = "never",
  className,
}: {
  value?: string
  fallback?: string
  className?: string
}) {
  const [label, setLabel] = React.useState(() => formatRelativeTime(value, fallback))

  React.useEffect(() => {
    setLabel(formatRelativeTime(value, fallback))

    if (!value) {
      return
    }

    const timer = window.setInterval(() => {
      setLabel(formatRelativeTime(value, fallback))
    }, SECOND)

    return () => window.clearInterval(timer)
  }, [fallback, value])

  return (
    <span className={className} title={value}>
      {label}
    </span>
  )
}
