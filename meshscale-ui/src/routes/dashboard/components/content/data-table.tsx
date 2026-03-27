import * as React from "react"
import {
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  ChevronsLeft,
  ChevronsRight,
  CheckCircle2,
  MoreVertical,
  GripVertical,
  Columns3,
  Loader2,
  Plus,
  TrendingUp,
} from "lucide-react"
import { Area, AreaChart, CartesianGrid, XAxis } from "recharts"
import { z } from "zod"
import { useLiveQuery } from "dexie-react-hooks"
import { db } from "@/lib/db"

import { useIsMobile } from "@/hooks/use-mobile"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
  type ChartConfig,
} from "@/components/ui/chart"
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
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { Separator } from "@/components/ui/separator"
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

export const schema = z.object({
  id: z.number(),
  service: z.string(),
  type: z.string(),
  status: z.string(),
  region: z.string(),
  uptime: z.string(),
  deployedBy: z.string(),
})

export function DataTable() {
  const projects = useLiveQuery(() => db.projects.toArray(), []) ?? []

  // Map Project rows to the table schema shape
  const data: z.infer<typeof schema>[] = projects.map((p, i) => ({
    id: i + 1,
    service: p.name,
    type: p.type
      .split("-")
      .map((w) => w[0].toUpperCase() + w.slice(1))
      .join(" "),
    status:
      p.status === "running"
        ? "Running"
        : p.status === "stopped"
          ? "Stopped"
          : p.status === "deploying"
            ? "Deploying"
            : "Error",
    region: p.region,
    uptime: p.uptime,
    deployedBy: p.lastDeployedBy,
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

  const totalPages = Math.ceil(data.length / pageSize)
  const startIndex = currentPage * pageSize
  const endIndex = startIndex + pageSize
  const currentData = data.slice(startIndex, endIndex)

  const toggleRow = (id: number) => {
    const newSelected = new Set(selectedRows)
    if (newSelected.has(id)) {
      newSelected.delete(id)
    } else {
      newSelected.add(id)
    }
    setSelectedRows(newSelected)
  }

  const toggleAllRows = () => {
    if (selectedRows.size === currentData.length) {
      setSelectedRows(new Set())
    } else {
      setSelectedRows(new Set(currentData.map(item => item.id)))
    }
  }

  return (
    <Tabs
      defaultValue="outline"
      className="w-full flex-col justify-start gap-6"
    >
      <div className="flex items-center justify-between px-4 lg:px-6">
        <Label htmlFor="view-selector" className="sr-only">
          View
        </Label>
        <Select defaultValue="outline">
          <SelectTrigger
            className="flex w-fit @4xl/main:hidden"
            size="sm"
            id="view-selector"
          >
            <SelectValue placeholder="Select a view" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="outline">Services</SelectItem>
            <SelectItem value="past-performance">Deployments</SelectItem>
            <SelectItem value="key-personnel">Alerts</SelectItem>
            <SelectItem value="focus-documents">Costs</SelectItem>
          </SelectContent>
        </Select>
        <TabsList className="**:data-[slot=badge]:bg-muted-foreground/30 hidden **:data-[slot=badge]:size-5 **:data-[slot=badge]:rounded-full **:data-[slot=badge]:px-1 @4xl/main:flex">
          <TabsTrigger value="outline">Services</TabsTrigger>
          <TabsTrigger value="past-performance">
            Deployments <Badge variant="secondary">3</Badge>
          </TabsTrigger>
          <TabsTrigger value="key-personnel">
            Alerts <Badge variant="secondary">2</Badge>
          </TabsTrigger>
          <TabsTrigger value="focus-documents">Costs</TabsTrigger>
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
                  onCheckedChange={(checked) =>
                    setVisibleColumns(prev => ({ ...prev, [key]: checked }))
                  }
                >
                  {key}
                </DropdownMenuCheckboxItem>
              ))}
            </DropdownMenuContent>
          </DropdownMenu>
          <Button variant="outline" size="sm">
            <Plus />
            <span className="hidden lg:inline">Add Service</span>
          </Button>
        </div>
      </div>
      <TabsContent
        value="outline"
        className="relative flex flex-col gap-4 overflow-auto px-4 lg:px-6"
      >
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
                      checked={selectedRows.size === currentData.length && currentData.length > 0}
                      onCheckedChange={toggleAllRows}
                      aria-label="Select all"
                    />
                  </div>
                </TableHead>
                {visibleColumns.service && <TableHead>Service</TableHead>}
                {visibleColumns.type && <TableHead>Type</TableHead>}
                {visibleColumns.status && <TableHead>Status</TableHead>}
                {visibleColumns.region && <TableHead>Region</TableHead>}
                {visibleColumns.uptime && <TableHead className="text-right">Uptime</TableHead>}
                {visibleColumns.deployedBy && <TableHead>Deployed By</TableHead>}
                <TableHead className="w-8"></TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {currentData.length ? (
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
                        <div className="w-32">
                          <Badge variant="outline" className="text-muted-foreground px-1.5">
                            {item.type}
                          </Badge>
                        </div>
                      </TableCell>
                    )}
                    {visibleColumns.status && (
                      <TableCell>
                        <Badge variant="outline" className="text-muted-foreground px-1.5">
                          {item.status === "Running" ? (
                            <CheckCircle2 className="fill-green-500 dark:fill-green-400" />
                          ) : item.status === "Deploying" ? (
                            <Loader2 className="animate-spin text-yellow-500" />
                          ) : (
                            <Loader2 />
                          )}
                          {item.status}
                        </Badge>
                      </TableCell>
                    )}
                    {visibleColumns.region && (
                      <TableCell>
                        <span className="text-muted-foreground text-sm">{item.region}</span>
                      </TableCell>
                    )}
                    {visibleColumns.uptime && (
                      <TableCell className="text-right tabular-nums">
                        {item.uptime}
                      </TableCell>
                    )}
                    {visibleColumns.deployedBy && (
                      <TableCell>
                        {item.deployedBy}
                      </TableCell>
                    )}
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
                        <DropdownMenuContent align="end" className="w-32">
                          <DropdownMenuItem>Edit</DropdownMenuItem>
                          <DropdownMenuItem>Make a copy</DropdownMenuItem>
                          <DropdownMenuItem>Favorite</DropdownMenuItem>
                          <DropdownMenuSeparator />
                          <DropdownMenuItem>Delete</DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </TableCell>
                  </TableRow>
                ))
              ) : (
                <TableRow>
                  <TableCell colSpan={9} className="h-24 text-center">
                    No results.
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
                onClick={() => setCurrentPage(p => Math.max(0, p - 1))}
                disabled={currentPage === 0}
              >
                <span className="sr-only">Go to previous page</span>
                <ChevronLeft />
              </Button>
              <Button
                variant="outline"
                className="size-8"
                size="icon"
                onClick={() => setCurrentPage(p => Math.min(totalPages - 1, p + 1))}
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
      <TabsContent
        value="past-performance"
        className="flex flex-col px-4 lg:px-6"
      >
        <div className="aspect-video w-full flex-1 rounded-lg border border-dashed"></div>
      </TabsContent>
      <TabsContent value="key-personnel" className="flex flex-col px-4 lg:px-6">
        <div className="aspect-video w-full flex-1 rounded-lg border border-dashed"></div>
      </TabsContent>
      <TabsContent
        value="focus-documents"
        className="flex flex-col px-4 lg:px-6"
      >
        <div className="aspect-video w-full flex-1 rounded-lg border border-dashed"></div>
      </TabsContent>
    </Tabs>
  )
}

const chartData = [
  { month: "January", desktop: 186, mobile: 80 },
  { month: "February", desktop: 305, mobile: 200 },
  { month: "March", desktop: 237, mobile: 120 },
  { month: "April", desktop: 73, mobile: 190 },
  { month: "May", desktop: 209, mobile: 130 },
  { month: "June", desktop: 214, mobile: 140 },
]

const chartConfig = {
  desktop: {
    label: "Desktop",
    color: "var(--primary)",
  },
  mobile: {
    label: "Mobile",
    color: "var(--primary)",
  },
} satisfies ChartConfig

function TableCellViewer({ item }: { item: z.infer<typeof schema> }) {
  const isMobile = useIsMobile()

  return (
    <Drawer direction={isMobile ? "bottom" : "right"}>
      <DrawerTrigger asChild>
        <Button variant="link" className="text-foreground w-fit px-0 text-left">
          {item.service}
        </Button>
      </DrawerTrigger>
      <DrawerContent>
        <DrawerHeader className="gap-1">
          <DrawerTitle>{item.service}</DrawerTitle>
          <DrawerDescription>
            Service details and deployment information
          </DrawerDescription>
        </DrawerHeader>
        <div className="flex flex-col gap-4 overflow-y-auto px-4 text-sm">
          {!isMobile && (
            <>
              <ChartContainer config={chartConfig}>
                <AreaChart
                  accessibilityLayer
                  data={chartData}
                  margin={{
                    left: 0,
                    right: 10,
                  }}
                >
                  <CartesianGrid vertical={false} />
                  <XAxis
                    dataKey="month"
                    tickLine={false}
                    axisLine={false}
                    tickMargin={8}
                    tickFormatter={(value) => value.slice(0, 3)}
                    hide
                  />
                  <ChartTooltip
                    cursor={false}
                    content={<ChartTooltipContent indicator="dot" />}
                  />
                  <Area
                    dataKey="mobile"
                    type="natural"
                    fill="var(--color-mobile)"
                    fillOpacity={0.6}
                    stroke="var(--color-mobile)"
                    stackId="a"
                  />
                  <Area
                    dataKey="desktop"
                    type="natural"
                    fill="var(--color-desktop)"
                    fillOpacity={0.4}
                    stroke="var(--color-desktop)"
                    stackId="a"
                  />
                </AreaChart>
              </ChartContainer>
              <Separator />
              <div className="grid gap-2">
                <div className="flex gap-2 leading-none font-medium">
                  Requests trending up by 5.2% this month{" "}
                  <TrendingUp className="size-4" />
                </div>
                <div className="text-muted-foreground">
                  Showing request volume for the last 6 months.
                </div>
              </div>
              <Separator />
            </>
          )}
          <form className="flex flex-col gap-4">
            <div className="flex flex-col gap-3">
              <Label htmlFor="service">Service Name</Label>
              <Input id="service" defaultValue={item.service} />
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="flex flex-col gap-3">
                <Label htmlFor="type">Type</Label>
                <Select defaultValue={item.type}>
                  <SelectTrigger id="type" className="w-full">
                    <SelectValue placeholder="Select a type" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="Website">Website</SelectItem>
                    <SelectItem value="Game Server">Game Server</SelectItem>
                    <SelectItem value="API">API</SelectItem>
                    <SelectItem value="Worker">Worker</SelectItem>
                    <SelectItem value="Cron Job">Cron Job</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="flex flex-col gap-3">
                <Label htmlFor="status">Status</Label>
                <Select defaultValue={item.status}>
                  <SelectTrigger id="status" className="w-full">
                    <SelectValue placeholder="Select a status" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="Running">Running</SelectItem>
                    <SelectItem value="Stopped">Stopped</SelectItem>
                    <SelectItem value="Deploying">Deploying</SelectItem>
                    <SelectItem value="Error">Error</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="flex flex-col gap-3">
                <Label htmlFor="region">Region</Label>
                <Input id="region" defaultValue={item.region} />
              </div>
              <div className="flex flex-col gap-3">
                <Label htmlFor="uptime">Uptime</Label>
                <Input id="uptime" defaultValue={item.uptime} readOnly />
              </div>
            </div>
            <div className="flex flex-col gap-3">
              <Label htmlFor="deployedBy">Deployed By</Label>
              <Select defaultValue={item.deployedBy}>
                <SelectTrigger id="deployedBy" className="w-full">
                  <SelectValue placeholder="Select a deployer" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="Eddie Lake">Eddie Lake</SelectItem>
                  <SelectItem value="Jamik Tashpulatov">
                    Jamik Tashpulatov
                  </SelectItem>
                  <SelectItem value="Emily Whalen">Emily Whalen</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </form>
        </div>
        <DrawerFooter>
          <Button>Save Changes</Button>
          <DrawerClose asChild>
            <Button variant="outline">Done</Button>
          </DrawerClose>
        </DrawerFooter>
      </DrawerContent>
    </Drawer>
  )
}
