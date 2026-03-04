import { DollarSign, TrendingUp, TrendingDown } from "lucide-react"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"

const costData = [
  {
    category: "Infrastructure",
    amount: 12450,
    change: 8.2,
    trend: "up",
  },
  {
    category: "Personnel",
    amount: 45600,
    change: -2.1,
    trend: "down",
  },
  {
    category: "Software",
    amount: 8900,
    change: 15.3,
    trend: "up",
  },
]

export function CostBreakdown() {
  const totalCost = costData.reduce((sum, item) => sum + item.amount, 0)

  return (
    <Card className="@container/card h-full">
      <CardHeader>
        <CardTitle>Cost Breakdown</CardTitle>
        <CardDescription>Monthly expenses by category</CardDescription>
      </CardHeader>
      <CardContent className="flex h-[250px] flex-col space-y-4 overflow-y-auto">
        <div className="flex items-center justify-between rounded-lg border p-4">
          <div className="flex items-center gap-2">
            <div className="bg-primary/10 flex size-10 items-center justify-center rounded-full">
              <DollarSign className="text-primary size-5" />
            </div>
            <div>
              <p className="text-muted-foreground text-sm">Total Cost</p>
              <p className="text-2xl font-semibold">
                ${totalCost.toLocaleString()}
              </p>
            </div>
          </div>
        </div>

        <div className="space-y-3">
          {costData.map((item) => (
            <div
              key={item.category}
              className="flex items-center justify-between rounded-lg border p-4"
            >
              <div className="flex-1">
                <p className="font-medium">{item.category}</p>
                <p className="text-muted-foreground text-sm">
                  ${item.amount.toLocaleString()}
                </p>
              </div>
              <Badge
                variant="outline"
                className={
                  item.trend === "up"
                    ? "text-green-600 dark:text-green-400"
                    : "text-red-600 dark:text-red-400"
                }
              >
                {item.trend === "up" ? (
                  <TrendingUp className="size-3" />
                ) : (
                  <TrendingDown className="size-3" />
                )}
                {Math.abs(item.change)}%
              </Badge>
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  )
}
import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute(
  '/dashboard/components/content/cost-breakdown',
)({
  component: RouteComponent,
})

function RouteComponent() {
  return <div>Hello "/dashboard/components/content/cost-breakdown"!</div>
}
