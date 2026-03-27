import { Outlet, createRootRoute, Link } from '@tanstack/react-router'
import { TanStackRouterDevtoolsPanel } from '@tanstack/react-router-devtools'
import { TanStackDevtools } from '@tanstack/react-devtools'

export const Route = createRootRoute({
  notFoundComponent: NotFound,
  component: RootLayout,
})

function NotFound() {
  return (
    <div className="flex h-screen flex-col items-center justify-center gap-4 text-center">
      <p className="text-muted-foreground text-7xl font-bold">404</p>
      <div>
        <h1 className="text-xl font-semibold">Page not found</h1>
        <p className="text-muted-foreground mt-1 text-sm">
          The page you're looking for doesn't exist or has been moved.
        </p>
      </div>
      <Link
        to="/dashboard"
        className="mt-2 rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground transition-opacity hover:opacity-90"
      >
        Go to Dashboard
      </Link>
    </div>
  )
}

function RootLayout() {
  return (
    <>
      <Outlet />
      <TanStackDevtools
        config={{
          position: 'bottom-right',
        }}
        plugins={[
          {
            name: 'Tanstack Router',
            render: <TanStackRouterDevtoolsPanel />,
          },
        ]}
      />
    </>
  )
}
