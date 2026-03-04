import { useState } from "react"
import { Link } from "@tanstack/react-router"
import { ProjectsList } from "./projects-list"
import { EmptyProjects } from "./empty-projects"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"

// Mock data - replace with actual data fetching
const mockProjects = [
  {
    id: 1,
    name: "Website Redesign",
    description: "Complete overhaul of company website",
    status: "In Progress",
    progress: 65,
    dueDate: "2024-03-15",
    team: 5,
  },
  {
    id: 2,
    name: "Mobile App",
    description: "iOS and Android mobile application",
    status: "Planning",
    progress: 20,
    dueDate: "2024-04-30",
    team: 8,
  },
  {
    id: 3,
    name: "API Integration",
    description: "Third-party API integration",
    status: "In Progress",
    progress: 80,
    dueDate: "2024-02-28",
    team: 3,
  },
]

const mockDraftProjects = [
  {
    id: 4,
    name: "Marketing Campaign",
    description: "Q2 marketing campaign planning",
    status: "Planning",
    progress: 0,
    dueDate: "2024-05-01",
    team: 4,
  },
]

export function ProjectsContent() {
  const [projects] = useState(mockProjects)
  const [draftProjects] = useState(mockDraftProjects)

  if (projects.length === 0 && draftProjects.length === 0) {
    return <EmptyProjects />
  }

  return (
    <div className="flex flex-1 flex-col">
      <Tabs defaultValue="active" className="flex flex-1 flex-col">
        <div className="border-b px-4 py-2 lg:px-6">
          <TabsList>
            <TabsTrigger value="active">
              Active Projects ({projects.length})
            </TabsTrigger>
            <TabsTrigger value="drafts">
              Drafts ({draftProjects.length})
            </TabsTrigger>
          </TabsList>
        </div>
        <TabsContent value="active" className="flex-1">
          <ProjectsList projects={projects} />
        </TabsContent>
        <TabsContent value="drafts" className="flex-1">
          <ProjectsList projects={draftProjects} />
        </TabsContent>
      </Tabs>
    </div>
  )
}
import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/projects/components/projects-content')({
  component: RouteComponent,
})

function RouteComponent() {
  return <div>Hello "/projects/components/projects-content"!</div>
}
