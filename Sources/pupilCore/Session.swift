import Foundation
import LoggerAPI

public enum SessionMode {
    case text
    case streaming
}

public protocol Session {
    init(socket: GenericSocket, root: URL, delegate: SessionDelegate) throws
    var mode: SessionMode { get }
    var broadcastID: String? { get }
    var remoteHostname: String { get }
    var hashValue: Int { get }
    var bytesRead: UInt64 { get }
    func stop()
}

public protocol SessionDelegate {
    func disconnected(session: Session)
}

func ==(lhs: Session, rhs: Session) -> Bool {
    return lhs.hashValue == rhs.hashValue
}


/// PupilSession - Represents
public class PupilSession: Session {
    private var client: Client?
    private let delegate: SessionDelegate
    
    public var mode: SessionMode
    public var broadcastID: String?
    
    private var avsession: AVSession?
    private var root: URL
    
    public private(set) var bytesRead: UInt64 = 0
    
    public var remoteHostname: String = ""

    public var hashValue: Int {
        if let c = self.client {
            return Int(c.socket.socketfd)
        }
        return -1
    }
    
    public required init(socket: GenericSocket,
                         root: URL,
                         delegate: SessionDelegate) throws
    {
        Log.info("Connection from \(socket.remoteHostname)")

        self.delegate = delegate
        self.root     = root
        self.mode     = .text
        
        self.client   = PupilClient(socket: socket) { _ in self.stop() }

        self.remoteHostname = self.client!.hostName
        self.client?.onRead = self.read
        _ = try self.client?.write(ServerTextResponse.connect.rawValue)
        
        Log.verbose("\(self.client!.hostName) greeted")
    }
    
    private func read(client: Client, data: Data) throws {
        switch self.mode {
        case .text:
            try self.handle(text: data)
        case .streaming:
            self.handle(bytes: [UInt8](data))
        }
    }
    
    private func handle(text data: Data) throws {
        if let response = String(data: data, encoding: .utf8) {
            let broadcastID  = response.replacingOccurrences(of: "\n",
                                                            with: "",
                                                            options: .regularExpression,
                                                            range: nil)
            self.broadcastID = broadcastID
            self.mode        = .streaming
            Log.info("\(self.client!.hostName) set \(broadcastID)")
            
            // Setup the AVSession for handling media portion of the protocol
            self.avsession = try AVSession(broadcastID: self.broadcastID!, root: self.root)
            _ = try self.client?.write(ServerTextResponse.begin.rawValue)
            Log.info("\(self.client!.hostName) \(broadcastID) sent BEGIN")
        }
    }
    
    private func handle(bytes data: [UInt8]) {
        self.bytesRead += UInt64(data.count)
        self.avsession?.read(data)
    }
    
    public func stop() {
        Log.debug("\(self.client!.hostName) session got close")
        if let av = self.avsession {
            Log.info("Notifying session to cleanup")
            av.stop {
                Log.info("Outstanding session tasks complete")
                self.delegate.disconnected(session: self)
            }
        } else {
            Log.info("No AV session present.  Disconnecting immediately")
            self.delegate.disconnected(session: self)
        }
    }

}
