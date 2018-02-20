import Foundation
import Socket
import LoggerAPI

public typealias ClientStateCallback = (Client) -> Void
public typealias ClientReadCallback  = (Client, Data) throws -> Void

public protocol Client {
    var hostName: String { get }

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
    public var hostName: String
    public var port: Int32?
    
    fileprivate var rwq: DispatchQueue
    fileprivate var onClose: ClientStateCallback?
    public var onRead: ClientReadCallback?
    
    public required init(socket: GenericSocket, onClose: ClientStateCallback?) {
        self.socket   = socket
        self.hostName = socket.remoteHostname
        
        self.rwq    = DispatchQueue(label: "\(socket.socketfd).rwq",
                                      qos: .default,
                               attributes: DispatchQueue.Attributes(rawValue: 0),
                     autoreleaseFrequency: .inherit,
                                   target: nil)
        
        self.onClose = onClose
        self.rwq.async { self.mainReadLoop() }
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
                readData.count = 0
            } while shouldKeepRunning
            
        } catch let err {
            Log.error("\(self.hostName) read error: \(err)")
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
    }
    
}
