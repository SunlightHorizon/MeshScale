# MeshScale

MeshScale is a Swift-based control plane for deploying Swift-defined infrastructure onto a distributed worker fleet.

Today the project is built around a few core ideas:

- Swift is the deployment language. You deploy an `infrastructure.swift`-style app, not just a static JSON manifest.
- The control plane compiles and runs that Swift app, calls `initialize(project:)` once, then calls `tick(project:)` continuously.
- FoundationDB is the source of truth for cluster state.
- NetBird is the network fabric between control planes and workers.
- The MeshScale dashboard is itself shipped as a MeshScale-managed app.

## Current Shape

MeshScale currently includes:

- `meshscale-swift`: the CLI, control plane runtime, worker runtime, FoundationDB store, and setup/install flow.
- `meshscale-ui`: the web dashboard bundled and served as a managed MeshScale app.
- `meshscale-react-native`: early mobile client work.

Key commands exposed by the CLI:

- `meshscale install`
- `meshscale setup`
- `meshscale auth login`
- `meshscale control-plane start`
- `meshscale worker start`
- `meshscale deploy`
- `meshscale status`
- `meshscale demo`

## Architecture

At a high level:

1. A control plane stores desired state, worker state, assignments, and project metadata in FoundationDB.
2. A deployed Swift app produces desired resources on each `tick(project:)`.
3. The control plane turns those resources into planned containers and worker assignments.
4. Workers reconcile those assignments into Docker containers.
5. The dashboard connects to the control plane over websockets for live status.
6. NetBird provides the mesh network used by control planes and workers.

## Installed Usage

The intended end-user flow is:

1. Install the `meshscale` CLI.
2. Download MeshScale toolchains with `meshscale install`.
3. Run mandatory host setup with `meshscale setup`.
4. Start a control plane or worker.

MeshScale expects installed toolchains under:

- `~/.meshscale/toolchains/<version>/control-plane`
- `~/.meshscale/toolchains/<version>/worker`

### First Control Plane

For the first control plane in a brand-new cluster, bootstrap setup is special because there is nothing to connect to yet.

Run the setup command with real `sudo`:

```bash
sudo meshscale setup --bootstrap-cluster --role control-plane
```

That flow is meant to:

- install or verify NetBird
- bootstrap the local NetBird control plane
- create the initial NetBird admin account
- create a setup key for the local node
- install or verify FoundationDB for the control plane
- persist the resulting configuration into `~/.meshscale/setup.json`

After setup, start the control plane:

```bash
meshscale control-plane start
```

### Additional Workers

Workers require NetBird setup but not FoundationDB:

```bash
sudo meshscale setup --role worker
meshscale worker start --region eu-west-1
```

### Authenticating and Deploying

The CLI deploy path currently requires saved auth:

```bash
meshscale auth login
meshscale deploy --file infrastructure.swift
```

Or deploy the built-in example:

```bash
meshscale demo
```

### Inspecting State

```bash
meshscale status
meshscale status --json
```

## Repository Development

For contributors working from source, use the repo-local builds instead of installed toolchains.

### Requirements

- Swift 6 toolchain
- Bun for `meshscale-ui`
- Docker
- NetBird
- FoundationDB client/runtime, plus a reachable FoundationDB cluster file for the control plane

### Build

```bash
cd meshscale-ui
bun install
bun run build

cd ../meshscale-swift
swift build --build-path .build-fdb
```

### Start the Control Plane from Source

Repository development uses `--allow-local-build`:

```bash
cd meshscale-swift
MESHCALE_CONTROL_PLANE_PORT=8080 \
./.build-fdb/debug/MeshScaleCLI control-plane start --dev --allow-local-build
```

### Start a Worker from Source

```bash
cd meshscale-swift
./.build-fdb/debug/MeshScaleCLI worker start --allow-local-build
```

### Dashboard

The control plane builds `meshscale-ui`, bundles it, and serves it through a managed nginx container.

In the current local dev setup you will usually see:

- control plane API on `http://127.0.0.1:8080`
- MeshScale dashboard on `http://127.0.0.1:18480`
- NetBird bootstrap dashboard on `http://127.0.0.1:18080`
- NetBird management/OIDC on `http://127.0.0.1:18081`

## Writing a MeshScale App

MeshScale apps are Swift source files that declare resources and respond to ticks.

Typical flow:

- implement `initialize(project:)` for one-time setup
- implement `tick(project:)` for recurring reconciliation
- declare resources such as services, caches, and databases
- publish dynamic values to the UI with `project.setOutput("key", to: value)`

The current example lives at:

- [Examples/infrastructure.swift](/Users/priamc/Coding/swift-projects/MeshScale/meshscale-swift/Examples/infrastructure.swift)

## Project Layout

- [meshscale-swift](/Users/priamc/Coding/swift-projects/MeshScale/meshscale-swift): Swift CLI, control plane, worker, store, setup/install flow
- [meshscale-ui](/Users/priamc/Coding/swift-projects/MeshScale/meshscale-ui): web dashboard
- [meshscale-react-native](/Users/priamc/Coding/swift-projects/MeshScale/meshscale-react-native): mobile client work
- [.github/workflows/meshscale-cli-release.yml](/Users/priamc/Coding/swift-projects/MeshScale/.github/workflows/meshscale-cli-release.yml): CLI/toolchain release workflow
- [.meshscale/linux-node-entrypoint.sh](/Users/priamc/Coding/swift-projects/MeshScale/.meshscale/linux-node-entrypoint.sh): helper for Linux node provisioning during cluster tests

## Notes

- MeshScale is currently opinionated toward FoundationDB-backed state. Local file store fallback is not part of the intended model.
- The dashboard is websocket-first and expects a live control plane.
- For JavaScript work in this repo, use Bun rather than npm or pnpm.
