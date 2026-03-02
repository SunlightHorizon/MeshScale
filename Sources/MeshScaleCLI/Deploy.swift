import Foundation
import ArgumentParser

extension MeshScaleCLI {
    struct Deploy: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "deploy",
            abstract: "Deploy infrastructure.swift to control plane"
        )
        
        @Option(name: .shortAndLong, help: "Path to infrastructure.swift")
        var file: String = "infrastructure.swift"
        
        func run() throws {
            guard FileManager.default.fileExists(atPath: file) else {
                print("❌ File not found: \(file)")
                throw ExitCode.failure
            }
            let source = try String(contentsOfFile: file, encoding: .utf8)
            
            guard ConfigManager.shared.hasAuth() else {
                print("❌ Not authenticated. Run 'meshscale auth login' first.")
                throw ExitCode.failure
            }
            let auth = try ConfigManager.shared.loadAuth()
            let base = auth.controlPlaneURL
            let baseWithScheme = (base.hasPrefix("http://") || base.hasPrefix("https://")) ? base : "http://\(base)"
            guard let url = URL(string: baseWithScheme + "/api/v1/deploy") else {
                print("❌ Invalid control plane URL: \(auth.controlPlaneURL)")
                throw ExitCode.failure
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(auth.token)", forHTTPHeaderField: "Authorization")
            request.httpBody = source.data(using: .utf8)
            
            let semaphore = DispatchSemaphore(value: 0)
            var statusCode: Int?
            var error: Error?
            URLSession.shared.dataTask(with: request) { _, response, err in
                error = err
                if let http = response as? HTTPURLResponse {
                    statusCode = http.statusCode
                }
                semaphore.signal()
            }.resume()
            semaphore.wait()
            
            if let error = error {
                print("❌ Failed to contact control plane: \(error)")
                throw ExitCode.failure
            }
            guard let code = statusCode, (200..<300).contains(code) else {
                print("❌ Control plane returned non-success status: \(statusCode ?? 0)")
                throw ExitCode.failure
            }
            print("✓ Deploy request accepted by control plane")
        }
    }
    
    struct Demo: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "demo",
            abstract: "Deploy the built-in example (Examples/infrastructure.swift)"
        )
        
        func run() throws {
            var deploy = Deploy()
            deploy.file = "Examples/infrastructure.swift"
            try deploy.run()
        }
    }
}
