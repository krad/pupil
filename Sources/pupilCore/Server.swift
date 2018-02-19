import Foundation
import Socket

/// Protocol describing behavior of a server
public protocol Server {
    /// The server root.  Where media data can be stored and/or processed
    var root: URL { get }
    
    /// TCP port the server listens/accepts connections on
    var port: Int32 { get }
    
    /// Represents the state of the server.  Whether it is accepting connections or not
    var started: Bool { get }

    /// An array of sessions connected to the server
    var sessions: [Session] { get }
    
    /// Creates a new server object
    ///
    /// - Parameters:
    ///   - port: Port to listen/accept connections on
    ///   - root: Directory to store / process media files.  Defaults to the current working directory.
    init(port: Int32, root: URL?)
    
    /// Begin listening & accepting new connections on port
    ///
    /// - Throws: Will throw if the server could not listen for new connections
    func start(_ onStart: (() -> (Void))?) throws
    
    /// Stops listening & accepting for new connections
    func stop()
}


/// Enum representing valid responses in the text portion of the streaming protocol
///
/// - connect: Returned when a client first connects to the server
/// - begin: Returned when the server is ready to begin accepting binary audio/video data
public enum ServerTextResponse: String {
    case connect = "HI\n"
    case begin   = "BEGIN\n"
}

public class PupilServer: Server, SessionDelegate {
    
    static let bufferSize = 4096
    
    public let port: Int32
    public let root: URL
    public var started: Bool {
        if let s = self.listenSocket {
            return s.isListening
        }
        return false
    }
    public var sessions: [Session] = []
    
    internal var listenSocket: Socket?
    internal var continueRunning = false
    
    private var listenQ = DispatchQueue.global(qos: .userInteractive)
    private var lockQ   = DispatchQueue(label: "pupil.server.socketLockQ")
    
    public required init(port: Int32, root: URL?) {
        self.port = port
        if let r = root { self.root = r }
        else {
            let cwd   = FileManager.default.currentDirectoryPath
            self.root = URL(fileURLWithPath: cwd)
        }
    }
    
    
    /// Create a listening socket and begin accepting connections
    ///
    /// - Parameter onStart: Closure called when the server is up and running
    /// - Throws: Throws an error when the server can't start
    public func start(_ onStart: (() -> Void)?) throws {
        let listenSocket     = try Socket.create()
        try listenSocket.listen(on: Int(self.port))
        self.listenSocket    = listenSocket
        startListenEventLoop(listenSocket, onStart: onStart)
    }
    
    
    private func startListenEventLoop(_ socket: Socket, onStart: (() -> Void)?) {
        listenQ.async { [unowned self] in
            do {
                self.continueRunning = true
                onStart?()
                repeat {
                    let newSocket = try socket.acceptClientConnection()
                    let session   = try PSession(socket: newSocket,
                                                 root: self.root,
                                                 delegate: self)
                    self.connected(session)
                } while self.continueRunning
            } catch let err {
                print("Server err:", err)
            }
        }
    }
    
    private func connected(_ session: Session) {
        self.lockQ.sync {[unowned self, session] in self.sessions.append(session) }
    }
    
    public func disconnected(session: Session) {
        self.lockQ.sync {[unowned self, session] in
            if let idx = self.sessions.index(where: { $0 == session }) {
                self.sessions.remove(at: idx)
            }
        }
    }
    
    public func stop() {
        self.continueRunning = false
        
        for session in self.sessions {
            session.stop()
        }
        
        self.listenSocket?.close()
    }
}
