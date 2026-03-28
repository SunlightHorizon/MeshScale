import Foundation
import Hummingbird
import HummingbirdWebSocket
import MeshScaleControlPlaneRuntime
import MeshScaleStore
import MeshScaleWorkerRuntime
import NIOCore

@main
struct MeshScaleControlPlane {
    static func main() async throws {
        let environment = ProcessInfo.processInfo.environment
        let logPath: String
        #if os(Windows)
        let appData = ProcessInfo.processInfo.environment["APPDATA"] ?? ""
        logPath = appData + "\\MeshScale\\logs\\control-plane.log"
        #elseif os(macOS)
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        logPath = home + "/.config/meshscale/logs/control-plane.log"
        #else
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        logPath = home + "/.config/meshscale/logs/control-plane.log"
        #endif

        let logURL = URL(fileURLWithPath: logPath)
        let logger = Logger(logFile: logURL)
        let netBird = NetBirdClient(
            configuration: .fromEnvironment(role: .controlPlane),
            logger: { logger.log($0) }
        )

        logger.log("MeshScale Control Plane starting...")

        let netbirdIP: String
        do {
            let status = try netBird.ensureConnected()
            if status.enabled {
                if let ipv4 = status.ipv4 {
                    netbirdIP = ipv4
                    logger.log("NetBird connected on \(ipv4)")
                } else {
                    netbirdIP = ""
                    logger.log("NetBird enabled without an overlay IP")
                }
            } else {
                netbirdIP = ""
            }
        } catch {
            logger.log("Failed to initialize NetBird: \(error.localizedDescription)")
            throw error
        }

        let controlPlaneID = controlPlaneWorkerID(environment: environment)
        let region = controlPlaneRegion(environment: environment)
        let port = controlPlanePort(environment: environment)
        let bindHost = "0.0.0.0"
        let advertisedHost = controlPlaneAdvertisedHost(
            bindHost: bindHost,
            netbirdIP: netbirdIP,
            environment: environment
        )
        let store = MeshScaleStoreFactory.makeStore(environment: environment)
        let controlPlane = ControlPlane(
            id: controlPlaneID,
            region: region,
            apiURL: "http://\(advertisedHost):\(port)",
            netbirdIP: netbirdIP,
            logger: logger,
            store: store
        )
        await controlPlane.start()

        let embeddedWorker: Worker?
        if embeddedWorkerEnabled(environment: environment) {
            var managedFileBundles: [String: [ManagedFile]] = [:]
            if let dashboardFiles = controlPlane.managedFileBundle(named: "meshscale-dashboard") {
                managedFileBundles["meshscale-dashboard"] = dashboardFiles
            }
            let worker = Worker(
                id: controlPlaneID,
                type: .controlPlane,
                region: region,
                controlPlaneID: controlPlaneID,
                controlPlaneAPIURL: controlPlane.currentAPIURL(),
                managedFileBundles: managedFileBundles,
                store: store
            )
            worker.start()
            embeddedWorker = worker
        } else {
            embeddedWorker = nil
            logger.log("Embedded control-plane worker disabled")
        }

        logger.log("Control Plane running...")
        logger.log("Starting HTTP and WebSocket API on \(bindHost):\(port)")

        let router = Router(context: BasicWebSocketRequestContext.self)

        router.ws(
            "/ws/control-plane",
            shouldUpgrade: { _, _ in .upgrade([:]) }
        ) { inbound, outbound, _ in
            logger.log("WebSocket client connected")

            let streamTask = Task {
                await sendStatusSnapshot(controlPlane: controlPlane, outbound: outbound, logger: logger)

                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    await sendStatusSnapshot(controlPlane: controlPlane, outbound: outbound, logger: logger)
                }
            }

            defer {
                logger.log("WebSocket client disconnected")
                streamTask.cancel()
            }

            do {
                for try await message in inbound {
                    let packet = message
                    guard packet.opcode == .text else {
                        await sendSocketError(
                            "Only text websocket frames are supported.",
                            outbound: outbound,
                            requestId: nil,
                            logger: logger
                        )
                        continue
                    }

                    let text = String(buffer: packet.data)

                    await handleWebSocketMessage(
                        text,
                        controlPlane: controlPlane,
                        outbound: outbound,
                        logger: logger
                    )
                }
            } catch {
                logger.log("WebSocket client error: \(error.localizedDescription)")
            }
        }

        router.get("/api/v1/status", use: { _, _ async throws -> Response in
            let snapshot = await controlPlane.statusSnapshot()
            guard let data = encodeJSON(snapshot, logger: logger) else {
                return Response(status: .internalServerError, headers: defaultJSONHeaders())
            }

            return Response(
                status: .ok,
                headers: defaultJSONHeaders(),
                body: ResponseBody(byteBuffer: ByteBuffer(bytes: data))
            )
        })

        router.post("/api/v1/deploy", use: { request, _ async throws -> Response in
            let headers = defaultCORSHeaders()

            let buffer: ByteBuffer
            do {
                buffer = try await request.body.collect(upTo: 4 * 1024 * 1024)
            } catch {
                logger.log("Failed to read deploy body: \(error.localizedDescription)")
                return Response(status: .badRequest, headers: headers)
            }

            let data = Data(buffer.readableBytesView)
            guard !data.isEmpty || buffer.readableBytes == 0 else {
                return Response(status: .badRequest, headers: headers)
            }

            let contentType = request.headers[.contentType] ?? ""

            if contentType.contains("application/json") {
                guard let submission = decodeJSON(DeploymentSubmission.self, from: data, logger: logger) else {
                    return Response(status: .badRequest, headers: headers)
                }

                controlPlane.deployManifest(submission)
                return Response(status: .accepted, headers: headers)
            }

            guard let source = String(data: data, encoding: .utf8) else {
                return Response(status: .badRequest, headers: headers)
            }

            controlPlane.deployProject(source)
            return Response(status: .accepted, headers: headers)
        })

        router.get("/api/v1/netbird/status", use: { _, _ async throws -> Response in
            let status = netBird.currentStatus()
            guard let data = encodeJSON(status, logger: logger) else {
                return Response(status: .internalServerError, headers: defaultJSONHeaders())
            }

            return Response(
                status: .ok,
                headers: defaultJSONHeaders(),
                body: ResponseBody(byteBuffer: ByteBuffer(bytes: data))
            )
        })

        router.get("/api/v1/system-apps/meshscale-dashboard/files", use: { _, _ async throws -> Response in
            guard let files = controlPlane.managedFileBundle(named: "meshscale-dashboard"),
                  let data = encodeJSON(files, logger: logger) else {
                return Response(status: .notFound, headers: defaultJSONHeaders())
            }

            return Response(
                status: .ok,
                headers: defaultJSONHeaders(),
                body: ResponseBody(byteBuffer: ByteBuffer(bytes: data))
            )
        })

        router.get("/netbird/", use: { _, _ async throws -> Response in
            netBirdPageResponse(status: netBird.currentStatus())
        })

        let app = Application(
            router: router,
            server: .http1WebSocketUpgrade(webSocketRouter: router),
            configuration: .init(address: .hostname(bindHost, port: port))
        )
        try await runApplication(app, retaining: embeddedWorker)
    }
}

private func runApplication<Responder: HTTPResponder>(
    _ app: Application<Responder>,
    retaining worker: Worker?
) async throws {
    _ = worker
    try await app.runService()
}

private func handleWebSocketMessage(
    _ text: String,
    controlPlane: ControlPlane,
    outbound: WebSocketOutboundWriter,
    logger: Logger
) async {
    guard let data = text.data(using: .utf8),
          let message = decodeJSON(ControlPlaneSocketRequest.self, from: data, logger: logger)
    else {
        await sendSocketError("Invalid websocket payload.", outbound: outbound, requestId: nil, logger: logger)
        return
    }

    switch message.type {
    case "request-status":
        await sendStatusSnapshot(controlPlane: controlPlane, outbound: outbound, logger: logger)

    case "deploy-manifest":
        guard let submission = message.payload else {
            await sendSocketError(
                "Missing deployment manifest payload.",
                outbound: outbound,
                requestId: message.id,
                logger: logger
            )
            return
        }

        controlPlane.deployManifest(submission)
        await sendCommandResult(success: true, outbound: outbound, requestId: message.id, logger: logger)
        await sendStatusSnapshot(controlPlane: controlPlane, outbound: outbound, logger: logger)

    case "deploy-source":
        guard let source = message.source, !source.isEmpty else {
            await sendSocketError(
                "Missing deployment source payload.",
                outbound: outbound,
                requestId: message.id,
                logger: logger
            )
            return
        }

        controlPlane.deployProject(source)
        await sendCommandResult(success: true, outbound: outbound, requestId: message.id, logger: logger)
        await sendStatusSnapshot(controlPlane: controlPlane, outbound: outbound, logger: logger)

    default:
        await sendSocketError(
            "Unsupported websocket command: \(message.type)",
            outbound: outbound,
            requestId: message.id,
            logger: logger
        )
    }
}

private func sendStatusSnapshot(
    controlPlane: ControlPlane,
    outbound: WebSocketOutboundWriter,
    logger: Logger
) async {
    let snapshot = await controlPlane.statusSnapshot()
    let message = ControlPlaneSocketResponse(
        type: "status-snapshot",
        id: nil,
        success: nil,
        error: nil,
        snapshot: snapshot
    )
    await sendSocketMessage(message, outbound: outbound, logger: logger)
}

private func sendCommandResult(
    success: Bool,
    outbound: WebSocketOutboundWriter,
    requestId: String?,
    logger: Logger
) async {
    let message = ControlPlaneSocketResponse(
        type: "command-result",
        id: requestId,
        success: success,
        error: success ? nil : "Command failed.",
        snapshot: nil
    )
    await sendSocketMessage(message, outbound: outbound, logger: logger)
}

private func sendSocketError(
    _ error: String,
    outbound: WebSocketOutboundWriter,
    requestId: String?,
    logger: Logger
) async {
    let message = ControlPlaneSocketResponse(
        type: requestId == nil ? "error" : "command-result",
        id: requestId,
        success: requestId == nil ? nil : false,
        error: error,
        snapshot: nil
    )
    await sendSocketMessage(message, outbound: outbound, logger: logger)
}

private func sendSocketMessage(
    _ message: ControlPlaneSocketResponse,
    outbound: WebSocketOutboundWriter,
    logger: Logger
) async {
    guard let data = encodeJSON(message, logger: logger),
          let text = String(data: data, encoding: .utf8)
    else {
        logger.log("Failed to encode websocket message")
        return
    }

    do {
        try await outbound.write(.text(text))
    } catch {
        logger.log("Failed to write websocket message: \(error.localizedDescription)")
    }
}

private func defaultCORSHeaders() -> HTTPFields {
    var headers = HTTPFields()
    headers[.accessControlAllowOrigin] = "*"
    return headers
}

private func defaultJSONHeaders() -> HTTPFields {
    var headers = defaultCORSHeaders()
    headers[.contentType] = "application/json"
    return headers
}

private func defaultHTMLHeaders() -> HTTPFields {
    var headers = defaultCORSHeaders()
    headers[.contentType] = "text/html; charset=utf-8"
    return headers
}

private func netBirdPageResponse(status: NetBirdStatus) -> Response {
    let html = renderNetBirdPage(status: status)
    return Response(
        status: .ok,
        headers: defaultHTMLHeaders(),
        body: ResponseBody(byteBuffer: ByteBuffer(string: html))
    )
}

private func renderNetBirdPage(status: NetBirdStatus) -> String {
    let connected = status.connected ? "Connected" : "Disconnected"
    let badgeColor = status.connected ? "#0f9d58" : "#d93025"
    let adminLink = status.adminURL.map {
        """
        <p><a href="\($0)" target="_blank" rel="noreferrer noopener">Open NetBird Admin</a></p>
        """
    } ?? "<p>No NetBird admin URL configured.</p>"
    let detail = escapeHTML(status.detail ?? status.lastError ?? "No NetBird diagnostics available.")
    let serviceStatus = escapeHTML(status.serviceStatus ?? "Service status unavailable.")
    let ipv4 = escapeHTML(status.ipv4 ?? "Not assigned")
    let hostname = escapeHTML(status.hostname ?? "Unknown")
    let managementURL = escapeHTML(status.managementURL ?? "Default")

    return """
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta http-equiv="refresh" content="10" />
        <title>MeshScale NetBird</title>
        <style>
          :root { color-scheme: light dark; }
          body {
            margin: 0;
            font-family: ui-sans-serif, system-ui, sans-serif;
            background: linear-gradient(135deg, #0b1220, #162033);
            color: #eef2ff;
          }
          main {
            max-width: 920px;
            margin: 0 auto;
            padding: 48px 24px 64px;
          }
          .hero {
            display: grid;
            gap: 12px;
            margin-bottom: 28px;
          }
          .badge {
            display: inline-flex;
            width: fit-content;
            align-items: center;
            gap: 8px;
            border-radius: 999px;
            padding: 8px 14px;
            background: rgba(255,255,255,0.08);
          }
          .dot {
            width: 10px;
            height: 10px;
            border-radius: 999px;
            background: \(badgeColor);
          }
          .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 16px;
          }
          .card {
            border: 1px solid rgba(255,255,255,0.12);
            border-radius: 18px;
            padding: 20px;
            background: rgba(8, 15, 28, 0.72);
            backdrop-filter: blur(16px);
          }
          h1, h2, p { margin: 0; }
          h1 { font-size: clamp(2rem, 4vw, 3rem); }
          h2 { font-size: 1rem; margin-bottom: 10px; color: #b8c4ff; }
          p + p { margin-top: 8px; }
          code, pre {
            font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
            white-space: pre-wrap;
            word-break: break-word;
          }
          a { color: #9cc2ff; }
        </style>
      </head>
      <body>
        <main>
          <section class="hero">
            <div class="badge"><span class="dot"></span><span>\(connected)</span></div>
            <h1>NetBird UI</h1>
            <p>MeshScale is exposing the current NetBird overlay state from the control plane.</p>
            \(adminLink)
          </section>
          <section class="grid">
            <article class="card">
              <h2>Overlay IPv4</h2>
              <p><code>\(ipv4)</code></p>
            </article>
            <article class="card">
              <h2>Hostname</h2>
              <p><code>\(hostname)</code></p>
            </article>
            <article class="card">
              <h2>Management URL</h2>
              <p><code>\(managementURL)</code></p>
            </article>
            <article class="card">
              <h2>Required</h2>
              <p><code>\(status.required ? "yes" : "no")</code></p>
            </article>
            <article class="card">
              <h2>Service</h2>
              <p><code>\(serviceStatus)</code></p>
            </article>
            <article class="card">
              <h2>Diagnostics</h2>
              <pre>\(detail)</pre>
            </article>
          </section>
        </main>
      </body>
    </html>
    """
}

private func escapeHTML(_ value: String) -> String {
    value
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}

private func encodeJSON<T: Encodable>(_ value: T, logger: Logger) -> Data? {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    do {
        return try encoder.encode(value)
    } catch {
        logger.log("Failed to encode JSON: \(error.localizedDescription)")
        return nil
    }
}

private func decodeJSON<T: Decodable>(_ type: T.Type, from data: Data, logger: Logger) -> T? {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    do {
        return try decoder.decode(type, from: data)
    } catch {
        logger.log("Failed to decode JSON: \(error.localizedDescription)")
        return nil
    }
}

private struct ControlPlaneSocketRequest: Codable {
    let type: String
    let id: String?
    let payload: DeploymentSubmission?
    let source: String?
}

private struct ControlPlaneSocketResponse: Codable {
    let type: String
    let id: String?
    let success: Bool?
    let error: String?
    let snapshot: ControlPlaneStatusSnapshot?
}

private func controlPlaneWorkerID(
    environment: [String: String] = ProcessInfo.processInfo.environment
) -> String {
    if let configured = environment["MESHCALE_CONTROL_PLANE_ID"], !configured.isEmpty {
        return configured
    }

    return "control-plane-\(ProcessInfo.processInfo.hostName)"
}

private func controlPlaneRegion(
    environment: [String: String] = ProcessInfo.processInfo.environment
) -> String {
    environment["MESHCALE_CONTROL_PLANE_REGION"] ?? "control-plane"
}

private func controlPlanePort(
    environment: [String: String] = ProcessInfo.processInfo.environment
) -> Int {
    Int(environment["MESHCALE_CONTROL_PLANE_PORT"] ?? "") ?? 8080
}

private func embeddedWorkerEnabled(
    environment: [String: String] = ProcessInfo.processInfo.environment
) -> Bool {
    let value = environment["MESHCALE_CONTROL_PLANE_EMBEDDED_WORKER"] ?? "true"
    return value.caseInsensitiveCompare("false") != .orderedSame && value != "0"
}

private func controlPlaneAdvertisedHost(
    bindHost: String,
    netbirdIP: String,
    environment: [String: String] = ProcessInfo.processInfo.environment
) -> String {
    if let configured = environment["MESHCALE_CONTROL_PLANE_PUBLIC_HOST"], !configured.isEmpty {
        return configured
    }
    if !netbirdIP.isEmpty {
        return netbirdIP
    }
    if bindHost == "0.0.0.0" {
        return "127.0.0.1"
    }
    return bindHost
}
