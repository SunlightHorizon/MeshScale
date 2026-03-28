import { useId, useState } from "react"
import { useNavigate } from "@tanstack/react-router"
import {
  AlertCircle,
  FileCode2,
  FileUp,
  Loader2,
  Sparkles,
} from "lucide-react"
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Separator } from "@/components/ui/separator"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Textarea } from "@/components/ui/textarea"
import { deployInfrastructure } from "@/lib/api"

export function CreateProjectForm() {
  const navigate = useNavigate()
  const fileInputId = useId()
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [submitError, setSubmitError] = useState<string | null>(null)
  const [sourceCode, setSourceCode] = useState("")
  const [selectedFileName, setSelectedFileName] = useState<string | null>(null)

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault()
    setSubmitError(null)

    const trimmed = sourceCode.trim()
    if (!trimmed) {
      setSubmitError("Paste Swift source or upload a .swift file before deploying.")
      return
    }

    setIsSubmitting(true)

    try {
      await deployInfrastructure(trimmed)
      navigate({ to: "/projects" })
    } catch (error) {
      setSubmitError(
        error instanceof Error ? error.message : "Failed to deploy Swift source.",
      )
      setIsSubmitting(false)
    }
  }

  const handleFileChange = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]
    if (!file) {
      return
    }

    try {
      const text = await file.text()
      setSourceCode(text)
      setSelectedFileName(file.name)
      setSubmitError(null)
    } catch {
      setSubmitError("Failed to read the selected Swift file.")
    }
  }

  return (
    <div className="flex flex-1 flex-col gap-6 p-4 lg:p-6">
      <div className="mx-auto w-full max-w-4xl">
        <form onSubmit={handleSubmit} className="space-y-6">
          {submitError && (
            <Alert variant="destructive">
              <AlertCircle className="size-4" />
              <AlertTitle>Deployment failed</AlertTitle>
              <AlertDescription>{submitError}</AlertDescription>
            </Alert>
          )}

          <Card>
            <CardHeader>
              <CardTitle>Deploy Swift Source</CardTitle>
              <CardDescription>
                Upload or paste the MeshScale Swift app you want the control plane to compile and tick continuously.
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <Tabs defaultValue="paste" className="gap-4">
                <TabsList>
                  <TabsTrigger value="paste">
                    <FileCode2 className="size-4" />
                    Paste Source
                  </TabsTrigger>
                  <TabsTrigger value="upload">
                    <FileUp className="size-4" />
                    Upload File
                  </TabsTrigger>
                </TabsList>

                <TabsContent value="paste" className="space-y-4">
                  <div className="grid gap-2">
                    <Label htmlFor="swift-source">Swift Source</Label>
                    <Textarea
                      id="swift-source"
                      value={sourceCode}
                      onChange={(event) => setSourceCode(event.target.value)}
                      rows={22}
                      className="font-mono text-sm"
                      placeholder={STARTER_TEMPLATE}
                    />
                  </div>
                  <div className="flex flex-wrap items-center gap-2">
                    <Button
                      type="button"
                      variant="outline"
                      onClick={() => setSourceCode(STARTER_TEMPLATE)}
                    >
                      <Sparkles className="size-4" />
                      Use Starter Template
                    </Button>
                    {selectedFileName && (
                      <span className="text-sm text-muted-foreground">
                        Loaded from {selectedFileName}
                      </span>
                    )}
                  </div>
                </TabsContent>

                <TabsContent value="upload" className="space-y-4">
                  <div className="rounded-xl border border-dashed bg-muted/20 p-6">
                    <div className="flex flex-col gap-3">
                      <div>
                        <h3 className="font-medium">Upload a Swift source file</h3>
                        <p className="text-sm text-muted-foreground">
                          Choose an `infrastructure.swift`-style file. The file contents will be loaded into the editor and deployed over the control-plane websocket.
                        </p>
                      </div>
                      <div className="flex flex-wrap items-center gap-3">
                        <Input
                          id={fileInputId}
                          type="file"
                          accept=".swift,text/x-swift,text/plain"
                          onChange={handleFileChange}
                          className="max-w-sm"
                        />
                        {selectedFileName && (
                          <span className="text-sm text-muted-foreground">
                            Current file: {selectedFileName}
                          </span>
                        )}
                      </div>
                    </div>
                  </div>
                </TabsContent>
              </Tabs>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Runtime Contract</CardTitle>
              <CardDescription>
                The control plane compiles your source and runs it as a long-lived runtime host.
              </CardDescription>
            </CardHeader>
            <CardContent className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
              <div className="rounded-lg border bg-muted/20 p-4">
                <div className="text-sm font-medium">`initialize(project:)`</div>
                <p className="mt-2 text-sm text-muted-foreground">
                  Optional. Runs once after the runtime host starts.
                </p>
              </div>
              <div className="rounded-lg border bg-muted/20 p-4">
                <div className="text-sm font-medium">`tick(project:)`</div>
                <p className="mt-2 text-sm text-muted-foreground">
                  Preferred. Runs every control-plane reconcile tick and can react to live state.
                </p>
              </div>
              <div className="rounded-lg border bg-muted/20 p-4">
                <div className="text-sm font-medium">Observed State</div>
                <p className="mt-2 text-sm text-muted-foreground">
                  `getMetrics(...)` and `getResourceHealth(...)` now reflect worker-reported service state during each tick.
                </p>
              </div>
              <div className="rounded-lg border bg-muted/20 p-4">
                <div className="text-sm font-medium">Live Outputs</div>
                <p className="mt-2 text-sm text-muted-foreground">
                  Use `project.setOutput("key", to: value)` inside `tick(project:)` to stream changing values into the UI.
                </p>
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
              {isSubmitting ? (
                <>
                  <Loader2 className="size-4 animate-spin" />
                  Deploying Source...
                </>
              ) : (
                "Deploy Swift App"
              )}
            </Button>
          </div>
        </form>
      </div>
    </div>
  )
}

const STARTER_TEMPLATE = `import Foundation
import MeshScaleControlPlaneRuntime

struct API: HTTPService {
  var name = "frontend"
  var replicas = 1
  var image = "nginxdemos/hello"
  var port = 80
  var cpu = 1
  var memory = 1.gb
  var latencySensitivity: LatencySensitivity = .medium
}

struct NetBirdUI: NetBirdDashboard {
  var name = "netbird_dashboard"
  var dashboardHostPort = 18080
  var managementHostPort = 18081
}

func initialize(project: MeshScaleProject) {
  project.sendAlert("Swift app deployed")
}

func tick(project: MeshScaleProject) {
  project.setDomain("localhost")
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  project.setOutput("current_time", to: formatter.string(from: Date()))
  project.addResource(API.self)
  // project.addResource(NetBirdUI.self)
}`
