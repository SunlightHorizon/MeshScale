import { useNavigate } from "@tanstack/react-router"
import { useState } from "react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { Separator } from "@/components/ui/separator"
import { db } from "@/lib/db"
import type { Project, Deployment, ProjectType } from "@/routes/projects/data"

export function CreateProjectForm() {
  const navigate = useNavigate()
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [name, setName] = useState("")
  const [description, setDescription] = useState("")
  const [type, setType] = useState<ProjectType>("website")
  const [region, setRegion] = useState("us-east-1")
  const [instances, setInstances] = useState(1)
  const [branch, setBranch] = useState("main")

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setIsSubmitting(true)

    const id = name
      .toLowerCase()
      .trim()
      .replace(/\s+/g, "-")
      .replace(/[^a-z0-9-]/g, "")

    const project: Project = {
      id,
      name: name.trim(),
      description: description.trim(),
      type,
      status: "deploying",
      region,
      uptime: "—",
      lastDeployed: "Just now",
      lastDeployedBy: "You",
      cpu: 0,
      memory: 0,
      instances: 0,
    }

    const deployment: Deployment = {
      id: `${id}-d1`,
      projectId: id,
      commit: "initial",
      branch,
      message: "Initial deployment",
      status: "in-progress",
      createdAt: "Just now",
      duration: "-",
      deployedBy: "You",
    }

    try {
      await db.projects.add(project)
      await db.deployments.add(deployment)
      navigate({ to: "/projects/$projectId", params: { projectId: id } })
    } catch (err) {
      console.error("Failed to create project", err)
      setIsSubmitting(false)
    }
  }

  return (
    <div className="flex flex-1 flex-col gap-6 p-4 lg:p-6">
      <div className="mx-auto w-full max-w-3xl">
        <form onSubmit={handleSubmit} className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>Project Details</CardTitle>
              <CardDescription>
                Basic information about your deployment project
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid gap-2">
                <Label htmlFor="name">Project Name *</Label>
                <Input
                  id="name"
                  placeholder="e.g. my-game-server"
                  required
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="description">Description</Label>
                <Textarea
                  id="description"
                  placeholder="What does this project do?"
                  rows={3}
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                />
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Deployment Configuration</CardTitle>
              <CardDescription>
                Configure how and where this project will be deployed
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid gap-4 md:grid-cols-2">
                <div className="grid gap-2">
                  <Label htmlFor="type">Project Type *</Label>
                  <Select
                    value={type}
                    onValueChange={(v) => setType(v as ProjectType)}
                  >
                    <SelectTrigger id="type">
                      <SelectValue placeholder="Select type" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="website">Website</SelectItem>
                      <SelectItem value="game-server">Game Server</SelectItem>
                      <SelectItem value="api">API</SelectItem>
                      <SelectItem value="worker">Worker</SelectItem>
                      <SelectItem value="cron">Cron Job</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div className="grid gap-2">
                  <Label htmlFor="region">Region *</Label>
                  <Select value={region} onValueChange={setRegion}>
                    <SelectTrigger id="region">
                      <SelectValue placeholder="Select region" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="us-east-1">
                        US East (N. Virginia)
                      </SelectItem>
                      <SelectItem value="us-west-2">
                        US West (Oregon)
                      </SelectItem>
                      <SelectItem value="eu-west-1">EU (Ireland)</SelectItem>
                      <SelectItem value="ap-southeast-1">
                        Asia Pacific (Singapore)
                      </SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <div className="grid gap-4 md:grid-cols-2">
                <div className="grid gap-2">
                  <Label htmlFor="instances">Initial Instances</Label>
                  <Input
                    id="instances"
                    type="number"
                    min="1"
                    value={instances}
                    onChange={(e) => setInstances(Number(e.target.value))}
                  />
                </div>
                <div className="grid gap-2">
                  <Label htmlFor="branch">Deploy Branch</Label>
                  <Input
                    id="branch"
                    value={branch}
                    onChange={(e) => setBranch(e.target.value)}
                  />
                </div>
              </div>
            </CardContent>
          </Card>

          <Separator />

          <div className="flex items-center justify-between">
            <Button
              type="button"
              variant="outline"
              onClick={() => navigate({ to: "/projects" })}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={isSubmitting}>
              {isSubmitting ? "Deploying..." : "Deploy Project"}
            </Button>
          </div>
        </form>
      </div>
    </div>
  )
}
