import * as React from "react"
import { Link } from "@tanstack/react-router"
import {
  AlertCircle,
  CheckCircle2,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  ChevronsLeft,
  ChevronsRight,
  Columns3,
  GripVertical,
  Loader2,
  MoreVertical,
  RefreshCw,
  Server,
  XCircle,
} from "lucide-react"
import { useIsMobile } from "@/hooks/use-mobile"
import { RelativeTime } from "@/components/relative-time"
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Checkbox } from "@/components/ui/checkbox"
import {
  Drawer,
  DrawerClose,
  DrawerContent,
  DrawerDescription,
  DrawerFooter,
  DrawerHeader,
  DrawerTitle,
  DrawerTrigger,
} from "@/components/ui/drawer"
import {
  DropdownMenu,
  DropdownMenuCheckboxItem,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { Label } from "@/components/ui/label"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import {
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger,
} from "@/components/ui/tabs"
import type { Deployment, Project } from "@/routes/projects/data"

interface DataTableProps {
  projects: Project[]
  deployments: Deployment[]
  isLoading: boolean
  error: string | null
  onRetry: () => Promise<void>
}

interface ServiceTableItem {
  id: number
  projectId: string
  service: string
  description: string
  type: string
  status: "Running" | "Stopped" | "Deploying" | "Error"
  region: string
  uptime: string
  deployedBy: string
  desiredInstances: number
  instances: number
  reservedCpu: string
  reservedMemory: string
  image?: string
  ports: string
  url?: string
  lastError?: string
}

const statusBadgeClassName: Record<ServiceTableItem["status"], string> = {
  Running: "text-green-600 dark:text-green-400",
  Stopped: "text-muted-foreground",
  Deploying: "text-yellow-600 dark:text-yellow-400",
  Error: "text-red-600 dark:text-red-400",
}

export function DataTable({
  projects,
  deployments,
  isLoading,
  error,
  onRetry,
}: DataTableProps) {
  const data: ServiceTableItem[] = projects.map((project, index) => ({
    id: index + 1,
    projectId: project.id,
    service: project.name,
    description: project.description,
    type: project.type
      .split("-")
      .map((part) => part[0].toUpperCase() + part.slice(1))
      .join(" "),
    status:
      project.status === "running"
        ? "Running"
        : project.status === "stopped"
          ? "Stopped"
          : project.status === "deploying"
            ? "Deploying"
            : "Error",
    region: project.region,
    uptime: project.uptime,
    deployedBy: project.lastDeployedBy,
    desiredInstances: project.desiredInstances ?? project.instances,
    instances: project.instances,
    reservedCpu: `${project.cpu} CPU`,
    reservedMemory: `${project.memory} GB`,
    image: project.image,
    ports:
      project.ports && project.ports.length > 0
        ? project.ports.join(", ")
        : "none",
    url: project.url,
    lastError: project.lastError,
  }))

  const [selectedRows, setSelectedRows] = React.useState<Set<number>>(new Set())
  const [currentPage, setCurrentPage] = React.useState(0)
  const [pageSize, setPageSize] = React.useState(10)
  const [visibleColumns, setVisibleColumns] = React.useState({
    service: true,
    type: true,
    status: true,
    region: true,
    uptime: true,
    deployedBy: true,
  })

  const totalPages = Math.max(1, Math.ceil(data.length / pageSize))
  const startIndex = currentPage * pageSize
  const currentData = data.slice(startIndex, startIndex + pageSize)
  const failingProjects = projects.filter((project) => project.status === "error").length

  React.useEffect(() => {
    setCurrentPage((page) => Math.min(page, totalPages - 1))
  }, [totalPages])

  const toggleRow = (id: number) => {
    setSelectedRows((current) => {
      const next = new Set(current)
      if (next.has(id)) {
        next.delete(id)
      } else {
        next.add(id)
      }
      return next
    })
  }

  const toggleAllRows = () => {
    setSelectedRows((current) => {
      if (currentData.length > 0 && current.size === currentData.length) {
        return new Set()
      }
      return new Set(currentData.map((item) => item.id))
    })
  }

  return (
    <Tabs
      defaultValue="services"
      className="w-full flex-col justify-start gap-6"
    >
      <div className="flex items-center justify-between px-4 lg:px-6">
        <Label htmlFor="view-selector" className="sr-only">
          View
        </Label>
        <Select defaultValue="services">
          <SelectTrigger
            className="flex w-fit @4xl/main:hidden"
            size="sm"
            id="view-selector"
          >
            <SelectValue placeholder="Select a view" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="services">Projects</SelectItem>
            <SelectItem value="rollouts">Rollouts</SelectItem>
          </SelectContent>
        </Select>
        <TabsList className="hidden @4xl/main:flex">
          <TabsTrigger value="services">Projects</TabsTrigger>
          <TabsTrigger value="rollouts">
            Rollouts <Badge variant="secondary">{deployments.length}</Badge>
          </TabsTrigger>
        </TabsList>
        <div className="flex items-center gap-2">
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="outline" size="sm">
                <Columns3 />
                <span className="hidden lg:inline">Customize Columns</span>
                <span className="lg:hidden">Columns</span>
                <ChevronDown />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-56">
              {Object.entries(visibleColumns).map(([key, value]) => (
                <DropdownMenuCheckboxItem
                  key={key}
                  className="capitalize"
                  checked={value}
                  onCheckedChange={(checked) => {
                    setVisibleColumns((current) => ({
                      ...current,
                      [key]: checked,
                    }))
                  }}
                >
                  {key}
                </DropdownMenuCheckboxItem>
              ))}
            </DropdownMenuContent>
          </DropdownMenu>
          <Button variant="outline" size="sm" onClick={() => void onRetry()}>
            <RefreshCw />
            <span className="hidden lg:inline">Refresh</span>
          </Button>
        </div>
      </div>

      <TabsContent
        value="services"
        className="relative flex flex-col gap-4 overflow-auto px-4 lg:px-6"
      >
        {error && (
          <Alert variant="destructive">
            <AlertCircle className="size-4" />
            <AlertTitle>Control plane refresh failed</AlertTitle>
            <AlertDescription>{error}</AlertDescription>
          </Alert>
        )}

        <div className="overflow-hidden rounded-lg border">
          <Table>
            <TableHeader className="bg-muted sticky top-0 z-10">
              <TableRow>
                <TableHead className="w-8">
                  <GripVertical className="text-muted-foreground size-3" />
                </TableHead>
                <TableHead className="w-8">
                  <div className="flex items-center justify-center">
                    <Checkbox
                      checked={
                        currentData.length > 0 &&
                        selectedRows.size === currentData.length
                      }
                      onCheckedChange={toggleAllRows}
                      aria-label="Select all"
                    />
                  </div>
                </TableHead>
                {visibleColumns.service && <TableHead>Project</TableHead>}
                {visibleColumns.type && <TableHead>Type</TableHead>}
                {visibleColumns.status && <TableHead>Status</TableHead>}
                {visibleColumns.region && <TableHead>Region</TableHead>}
                {visibleColumns.uptime && (
                  <TableHead className="text-right">Container State</TableHead>
                )}
                {visibleColumns.deployedBy && <TableHead>Managed By</TableHead>}
                <TableHead className="w-8" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {isLoading && data.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={8} className="h-24 text-center">
                    <div className="flex items-center justify-center gap-2 text-muted-foreground">
                      <Loader2 className="size-4 animate-spin" />
                      Loading projects...
                    </div>
                  </TableCell>
                </TableRow>
              ) : currentData.length > 0 ? (
                currentData.map((item) => (
                  <TableRow
                    key={item.id}
                    data-state={selectedRows.has(item.id) && "selected"}
                  >
                    <TableCell>
                      <Button
                        variant="ghost"
                        size="icon"
                        className="text-muted-foreground size-7 hover:bg-transparent"
                      >
                        <GripVertical className="text-muted-foreground size-3" />
                      </Button>
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center justify-center">
                        <Checkbox
                          checked={selectedRows.has(item.id)}
                          onCheckedChange={() => toggleRow(item.id)}
                          aria-label="Select row"
                        />
                      </div>
                    </TableCell>
                    {visibleColumns.service && (
                      <TableCell>
                        <TableCellViewer item={item} />
                      </TableCell>
                    )}
                    {visibleColumns.type && (
                      <TableCell>
                        <Badge variant="outline" className="text-muted-foreground px-1.5">
                          {item.type}
                        </Badge>
                      </TableCell>
                    )}
                    {visibleColumns.status && (
                      <TableCell>
                        <Badge
                          variant="outline"
                          className={`px-1.5 ${statusBadgeClassName[item.status]}`}
                        >
                          <StatusIcon status={item.status} />
                          {item.status}
                        </Badge>
                      </TableCell>
                    )}
                    {visibleColumns.region && (
                      <TableCell>
                        <span className="text-muted-foreground text-sm">
                          {item.region}
                        </span>
                      </TableCell>
                    )}
                    {visibleColumns.uptime && (
                      <TableCell className="text-right tabular-nums">
                        {item.instances}/{item.desiredInstances}
                      </TableCell>
                    )}
                    {visibleColumns.deployedBy && <TableCell>{item.deployedBy}</TableCell>}
                    <TableCell>
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button
                            variant="ghost"
                            className="data-[state=open]:bg-muted text-muted-foreground flex size-8"
                            size="icon"
                          >
                            <MoreVertical />
                            <span className="sr-only">Open menu</span>
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end" className="w-40">
                          <DropdownMenuItem asChild>
                            <Link
                              to="/projects/$projectId"
                              params={{ projectId: item.projectId }}
                            >
                              View details
                            </Link>
                          </DropdownMenuItem>
                          {item.url && (
                            <DropdownMenuItem asChild>
                              <a href={item.url} target="_blank" rel="noreferrer">
                                Open project
                              </a>
                            </DropdownMenuItem>
                          )}
                          <DropdownMenuSeparator />
                          <DropdownMenuItem onClick={() => void onRetry()}>
                            Refresh status
                          </DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </TableCell>
                  </TableRow>
                ))
              ) : (
                <TableRow>
                  <TableCell colSpan={8} className="h-24 text-center">
                    No projects reported by the control plane yet.
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </div>

        <div className="flex items-center justify-between px-4">
          <div className="text-muted-foreground hidden flex-1 text-sm lg:flex">
            {selectedRows.size} of {data.length} row(s) selected.
          </div>
          <div className="flex w-full items-center gap-8 lg:w-fit">
            <div className="hidden items-center gap-2 lg:flex">
              <Label htmlFor="rows-per-page" className="text-sm font-medium">
                Rows per page
              </Label>
              <Select
                value={`${pageSize}`}
                onValueChange={(value) => {
                  setPageSize(Number(value))
                  setCurrentPage(0)
                }}
              >
                <SelectTrigger size="sm" className="w-20" id="rows-per-page">
                  <SelectValue placeholder={pageSize} />
                </SelectTrigger>
                <SelectContent side="top">
                  {[10, 20, 30, 40, 50].map((size) => (
                    <SelectItem key={size} value={`${size}`}>
                      {size}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="flex w-fit items-center justify-center text-sm font-medium">
              Page {currentPage + 1} of {totalPages}
            </div>
            <div className="ml-auto flex items-center gap-2 lg:ml-0">
              <Button
                variant="outline"
                className="hidden h-8 w-8 p-0 lg:flex"
                onClick={() => setCurrentPage(0)}
                disabled={currentPage === 0}
              >
                <span className="sr-only">Go to first page</span>
                <ChevronsLeft />
              </Button>
              <Button
                variant="outline"
                className="size-8"
                size="icon"
                onClick={() => setCurrentPage((page) => Math.max(0, page - 1))}
                disabled={currentPage === 0}
              >
                <span className="sr-only">Go to previous page</span>
                <ChevronLeft />
              </Button>
              <Button
                variant="outline"
                className="size-8"
                size="icon"
                onClick={() =>
                  setCurrentPage((page) => Math.min(totalPages - 1, page + 1))
                }
                disabled={currentPage >= totalPages - 1}
              >
                <span className="sr-only">Go to next page</span>
                <ChevronRight />
              </Button>
              <Button
                variant="outline"
                className="hidden size-8 lg:flex"
                size="icon"
                onClick={() => setCurrentPage(totalPages - 1)}
                disabled={currentPage >= totalPages - 1}
              >
                <span className="sr-only">Go to last page</span>
                <ChevronsRight />
              </Button>
            </div>
          </div>
        </div>
      </TabsContent>

      <TabsContent value="rollouts" className="flex flex-col gap-4 px-4 lg:px-6">
        <div className="rounded-lg border">
          {deployments.length > 0 ? (
            deployments.map((deployment, index) => (
              <div
                key={deployment.id}
                className={`flex items-center justify-between gap-4 px-4 py-4 ${
                  index !== deployments.length - 1 ? "border-b" : ""
                }`}
              >
                <div className="min-w-0">
                  <div className="truncate text-sm font-medium">
                    {deployment.message}
                  </div>
                  <div className="mt-1 text-xs text-muted-foreground">
                    {deployment.branch} • {deployment.commit} • {deployment.deployedBy}
                  </div>
                </div>
                <div className="flex shrink-0 items-center gap-3 text-xs text-muted-foreground">
                  <Badge
                    variant="outline"
                    className={
                      deployment.status === "success"
                        ? "text-green-600 dark:text-green-400"
                        : deployment.status === "failed"
                          ? "text-red-600 dark:text-red-400"
                          : "text-yellow-600 dark:text-yellow-400"
                    }
                  >
                    <StatusIcon
                      status={
                        deployment.status === "success"
                          ? "Running"
                          : deployment.status === "failed"
                            ? "Error"
                            : "Deploying"
                      }
                    />
                    {deployment.status}
                  </Badge>
                  <RelativeTime value={deployment.createdAt} fallback="never" />
                </div>
              </div>
            ))
          ) : (
            <div className="px-4 py-8 text-sm text-muted-foreground">
              No rollout summaries yet.
            </div>
          )}
        </div>

        <div className="rounded-lg border border-dashed px-4 py-4 text-sm text-muted-foreground">
          {failingProjects > 0
            ? `${failingProjects} project${failingProjects !== 1 ? "s are" : " is"} currently reporting errors from worker state.`
            : "All currently reported projects are healthy."}
        </div>
      </TabsContent>
    </Tabs>
  )
}

function TableCellViewer({ item }: { item: ServiceTableItem }) {
  const isMobile = useIsMobile()

  return (
    <Drawer direction={isMobile ? "bottom" : "right"}>
      <DrawerTrigger asChild>
        <Button variant="link" className="text-foreground h-auto w-fit px-0 text-left">
          {item.service}
        </Button>
      </DrawerTrigger>
      <DrawerContent>
        <DrawerHeader className="gap-1">
          <DrawerTitle>{item.service}</DrawerTitle>
          <DrawerDescription>{item.description}</DrawerDescription>
        </DrawerHeader>
        <div className="grid gap-4 overflow-y-auto px-4 text-sm">
          <div className="grid gap-3 sm:grid-cols-2">
            <InfoCard label="Status" value={item.status} />
            <InfoCard label="Type" value={item.type} />
            <InfoCard label="Region" value={item.region} />
            <InfoCard
              label="Containers"
              value={`${item.instances}/${item.desiredInstances}`}
            />
            <InfoCard label="Reserved CPU" value={item.reservedCpu} />
            <InfoCard label="Reserved Memory" value={item.reservedMemory} />
            <InfoCard label="Ports" value={item.ports} />
            <InfoCard label="Managed By" value={item.deployedBy} />
          </div>

          {item.image && (
            <div className="rounded-lg border bg-muted/20 p-3">
              <div className="text-muted-foreground text-xs uppercase tracking-wide">
                Container image
              </div>
              <div className="mt-1 font-medium">{item.image}</div>
            </div>
          )}

          {item.lastError && (
            <Alert variant="destructive">
              <AlertCircle className="size-4" />
              <AlertTitle>Last worker error</AlertTitle>
              <AlertDescription>{item.lastError}</AlertDescription>
            </Alert>
          )}
        </div>
        <DrawerFooter>
          <Button asChild>
            <Link to="/projects/$projectId" params={{ projectId: item.projectId }}>
              Open Project
            </Link>
          </Button>
          {item.url && (
            <Button variant="outline" asChild>
              <a href={item.url} target="_blank" rel="noreferrer">
                Open Project URL
              </a>
            </Button>
          )}
          <DrawerClose asChild>
            <Button variant="outline">Done</Button>
          </DrawerClose>
        </DrawerFooter>
      </DrawerContent>
    </Drawer>
  )
}

function InfoCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border bg-muted/20 p-3">
      <div className="text-muted-foreground text-xs uppercase tracking-wide">
        {label}
      </div>
      <div className="mt-1 font-medium">{value}</div>
    </div>
  )
}

function StatusIcon({ status }: { status: ServiceTableItem["status"] }) {
  if (status === "Running") {
    return <CheckCircle2 className="fill-green-500 dark:fill-green-400" />
  }

  if (status === "Deploying") {
    return <Loader2 className="animate-spin text-yellow-500" />
  }

  if (status === "Error") {
    return <XCircle className="text-red-500" />
  }

  return <Server className="text-muted-foreground" />
}
