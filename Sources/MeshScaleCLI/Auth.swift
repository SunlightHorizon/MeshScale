import Foundation
import ArgumentParser

extension MeshScaleCLI {
    struct Auth: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "auth",
            abstract: "Authentication commands",
            subcommands: [Login.self, Logout.self]
        )
    }
    
    struct Login: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "login",
            abstract: "Login to a MeshScale control plane"
        )
        
        func run() throws {
            print("MeshScale Authentication")
            print("========================\n")
            
            print("Enter control plane URL (e.g., http://localhost:8080):")
            guard let url = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !url.isEmpty else {
                throw ExitCode.failure
            }
            
            print("Enter setup key or token:")
            guard let token = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !token.isEmpty else {
                throw ExitCode.failure
            }
            
            try ConfigManager.shared.saveAuth(controlPlaneURL: url, token: token)
            print("✅ Auth saved")
        }
    }
    
    struct Logout: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "logout",
            abstract: "Logout from MeshScale"
        )
        
        func run() throws {
            guard ConfigManager.shared.hasAuth() else {
                print("Not logged in")
                return
            }
            try ConfigManager.shared.removeAuth()
            print("✓ Logged out")
        }
    }
}
