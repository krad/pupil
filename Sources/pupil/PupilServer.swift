import Foundation
import Socket
import Dispatch
import morsel

class PupilServer {
    
    static let hiResponse: String   = "HI\n"
    static let goResponse: String   = "BEGIN\n"
    static let bufferSize           = 4096
    
    let port: Int
    var listenSocket: Socket? = nil
    var continueRunning       = true
    var sessions              = [Int32: PupilSession]()
    let socketLockQueue       = DispatchQueue(label: "tv.krad.pupil.socketLockQueue")
    
    private let root: URL
    
    init(port: Int, root: URL = URL(fileURLWithPath: ".")) {
        self.port = port
        self.root = root
    }
    
    deinit {
        // Close all open sockets...
        for session in sessions.values { session.close() { socket in } }
        self.listenSocket?.close()
    }
    
    func run() {
        let queue = DispatchQueue.global(qos: .userInteractive)
        
        queue.async { [unowned self] in
            do {
                try self.listenSocket = Socket.create()
                guard let socket = self.listenSocket else {
                    print("Unable to unwrap socket...")
                    return
                }
                
                try socket.listen(on: self.port)
                print("Listening on port: \(socket.listeningPort)")
                
                repeat {
                    let newSocket = try socket.acceptClientConnection()
                    print("Accepted connection from: \(newSocket.remoteHostname) on port \(newSocket.remotePort)")
                    if let sig = newSocket.signature { print("Socket Signature: \(sig.description)") }
                    self.addNewConnection(socket: newSocket)
                } while self.continueRunning
                
            }
            catch let error {
                guard let socketError = error as? Socket.Error else {
                    print("Unexpected error...")
                    return
                }
                if self.continueRunning { print("Error reported:\n \(socketError.description)") }
            }
        }
        
        dispatchMain()
    }
    
    func addNewConnection(socket: Socket) {
        do {
            let session = try PupilSession(socket: socket, root: self.root)
            
            // Add the new socket to the list of connected sockets...
            socketLockQueue.sync { [unowned self, socket] in self.sessions[socket.socketfd] = session }
            
            // Get the global concurrent queue...
            let queue = DispatchQueue.global(qos: .default)
            
            // Create the run loop work item and dispatch to the default priority global queue...
            queue.async { [unowned self, session] in
                var shouldKeepRunning = true
                
                var readData = Data(capacity: PupilServer.bufferSize)
                do {
                    // Write the welcome string...and wait for the broadcast id
                    try socket.write(from: PupilServer.hiResponse)
                    
                    repeat {
                        let bytesRead = try session.read(into: &readData)
                        if bytesRead > 0 {
                            switch session.state {
                            case .starting: self.handleText(data: readData, for: session)
                            case .streaming:
                                session.read(bytes: [UInt8](readData))
                                
                            default: _=0+0
                            }
                        } else {
                            shouldKeepRunning = false
                            break
                        }
                        readData.count = 0
                        
                    } while shouldKeepRunning
                    
                    print("Socket: \(socket.remoteHostname):\(socket.remotePort) closed...")
                    
                    session.close() { socket in
                        self.socketLockQueue.sync {
                            self.sessions[socket.socketfd] = nil
                        }
                    }
                    
                    
                } catch let error {
                    guard let socketError = error as? Socket.Error else {
                        print("Unexpected error by connection at \(socket.remoteHostname):\(socket.remotePort)...")
                        return
                    }
                    
                    if self.continueRunning {
                        print("Error reported by connection at \(socket.remoteHostname):\(socket.remotePort):\n \(socketError.description)")
                    }
                }
            }

        } catch let error {
            print("Error adding new connection:", error)
        }
    }
    
    private func handleText(data: Data, for session: PupilSession) {
        if let response = String(data: data, encoding: .utf8) {
            let broadcastID = response.replacingOccurrences(of: "\n",
                                                            with: "",
                                                            options: .regularExpression,
                                                            range: nil)
            session.broadcastID = broadcastID
            do { _ = try session.write(response: PupilServer.goResponse) }
            catch { session.close() { socket in } }
        } else { print("Error decoding response...") }
    }
    
    func shutdownServer() {
        print("\nShutdown in progress...")
        continueRunning = false
        
        // Close all open sockets...
        for session in sessions.values {
            session.close() { socket in
            }
        }
        
        listenSocket?.close()
        
        DispatchQueue.main.sync {
            exit(0)
        }
    }
}
