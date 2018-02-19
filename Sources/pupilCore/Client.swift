import Foundation
import Socket

public typealias ClientStateCallback = (Client) -> Void
public typealias ClientReadCallback  = (Client, Data) throws -> Void

public protocol Client {
    init(socket: GenericSocket, onClose: ClientStateCallback?)
    
    var socket: GenericSocket { get }
    var onRead: ClientReadCallback? { get set }
    
    func write(_ string: String?) throws -> Int
    func close()
}

func ==(lhs: Client, rhs: Client) -> Bool {
    return lhs.socket.socketfd == rhs.socket.socketfd
}

public enum ClientError: Error {
    case badString
}

public class PupilClient: Client {
    
    public var socket: GenericSocket
    public var hostName: String?
    public var port: Int32?
    
    fileprivate var rwq: DispatchQueue
    fileprivate var onClose: ClientStateCallback?
    public var onRead: ClientReadCallback?
    
    public required init(socket: GenericSocket, onClose: ClientStateCallback?) {
        self.socket = socket
        self.rwq    = DispatchQueue.global(qos: .default)
        
        self.onClose = onClose
        self.rwq.async {[unowned self] in self.mainReadLoop() }
    }
    
    private func mainReadLoop() {
        var shouldKeepRunning = true
        var readData = Data(capacity: PupilServer.bufferSize)
        do {
            repeat {
                let bytesRead = try self.socket.read(into: &readData)
                if bytesRead > 0 {
                    try self.onRead?(self, readData)
                } else {
                    if self.socket.remoteConnectionClosed {
                        shouldKeepRunning = false
                        self.onClose?(self)
                        break
                    }
                }
            } while shouldKeepRunning
            
        } catch {
            self.onClose?(self)
        }
    }
    
    public func write(_ string: String?) throws -> Int {
        if let data = string?.data(using: .utf8) {
            return try self.socket.write(from: data)
        }
        
        throw ClientError.badString
    }
    
    public func close() {
        self.socket.close()
        self.onClose?(self)
    }
}
