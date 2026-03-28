import Foundation
import MeshScaleStore

struct MeshScaleDashboardBundle: Sendable {
    static let bundleID = "meshscale-dashboard"
    static let defaultResourceName = "meshscale_dashboard"
    static let defaultPort = 18480

    let files: [ManagedFile]

    static func load(logger: Logger?) -> MeshScaleDashboardBundle? {
        let fileManager = FileManager.default
        let environment = ProcessInfo.processInfo.environment

        let assetsRoot: URL?
        if let configuredAssets = environment["MESHCALE_DASHBOARD_ASSETS_DIR"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !configuredAssets.isEmpty {
            assetsRoot = URL(fileURLWithPath: configuredAssets, isDirectory: true)
        } else {
            assetsRoot = locateAndBuildAssetsRoot(fileManager: fileManager, logger: logger)
        }

        guard let assetsRoot, fileManager.fileExists(atPath: assetsRoot.path) else {
            logger?.log("MeshScale dashboard assets are unavailable. Skipping bundled dashboard deployment.")
            return nil
        }

        do {
            let htmlFiles = try assetFiles(from: assetsRoot, fileManager: fileManager)
            let nginxConfig = ManagedFile(
                relativePath: "nginx/default.conf",
                mountPath: "/etc/nginx/conf.d/default.conf",
                content: nginxConfigContents()
            )
            return MeshScaleDashboardBundle(files: htmlFiles + [nginxConfig])
        } catch {
            logger?.log("Failed to load MeshScale dashboard assets: \(error.localizedDescription)")
            return nil
        }
    }

    private static func locateAndBuildAssetsRoot(fileManager: FileManager, logger: Logger?) -> URL? {
        let executable = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        let searchRoots = ancestorDirectories(for: executable.deletingLastPathComponent())

        for root in searchRoots {
            let sourceRoot = root.appendingPathComponent("meshscale-ui", isDirectory: true)
            let packageJSON = sourceRoot.appendingPathComponent("package.json")
            guard fileManager.fileExists(atPath: packageJSON.path) else {
                continue
            }

            if let builtAssets = buildDashboardAssets(at: sourceRoot, fileManager: fileManager, logger: logger) {
                return builtAssets
            }
        }

        return nil
    }

    private static func buildDashboardAssets(
        at sourceRoot: URL,
        fileManager: FileManager,
        logger: Logger?
    ) -> URL? {
        logger?.log("Building MeshScale UI dashboard bundle with Bun from \(sourceRoot.path)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["bun", "run", "build"]
        process.currentDirectoryURL = sourceRoot
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let assets = sourceRoot.appendingPathComponent(".output/public", isDirectory: true)
                if fileManager.fileExists(atPath: assets.path) {
                    return assets
                }
                logger?.log("MeshScale UI build finished but .output/public is missing at \(assets.path)")
                return nil
            }

            let stdoutMessage = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let stderrMessage = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let message = [stdoutMessage, stderrMessage]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            logger?.log("MeshScale UI dashboard build failed: \(message.isEmpty ? "unknown error" : message)")
        } catch {
            logger?.log("Failed to run Bun dashboard build: \(error.localizedDescription)")
        }

        return nil
    }

    private static func ancestorDirectories(for start: URL) -> [URL] {
        var results: [URL] = []
        var current = start
        for _ in 0..<8 {
            results.append(current)
            let next = current.deletingLastPathComponent()
            if next.path == current.path {
                break
            }
            current = next
        }
        return results
    }

    private static func assetFiles(from root: URL, fileManager: FileManager) throws -> [ManagedFile] {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [ManagedFile] = []
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else {
                continue
            }

            let relativePath = fileURL.path.replacingOccurrences(of: root.path + "/", with: "")
            let data = try Data(contentsOf: fileURL)
            if let text = String(data: data, encoding: .utf8),
               !data.contains(0) {
                files.append(
                    ManagedFile(
                        relativePath: relativePath,
                        mountPath: "/usr/share/nginx/html/\(relativePath)",
                        content: text,
                        encoding: .utf8
                    )
                )
            } else {
                files.append(
                    ManagedFile(
                        relativePath: relativePath,
                        mountPath: "/usr/share/nginx/html/\(relativePath)",
                        content: data.base64EncodedString(),
                        encoding: .base64
                    )
                )
            }
        }

        return files.sorted { $0.relativePath < $1.relativePath }
    }

    private static func nginxConfigContents() -> String {
        """
        server {
          listen 80;
          server_name _;
          root /usr/share/nginx/html;
          index index.html;
          add_header Cache-Control "no-store, no-cache, must-revalidate" always;

          location / {
            try_files $uri $uri/ /index.html;
          }
        }
        """
    }
}
