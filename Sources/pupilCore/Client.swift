import Foundation
import Socket

public typealias ClientStateCallback = (Client) -> Void

public protocol Client {
    init(socket: GenericSocket, onClose: ClientStateCallback?)
    var socket: GenericSocket { get }
}

func ==(lhs: Client, rhs: Client) -> Bool {
    return lhs.socket.socketfd == rhs.socket.socketfd
}

public class PupilClient: Client {
    
    public var socket: GenericSocket
    public var hostName: String?
    public var port: Int32?
    
    fileprivate var rwq: DispatchQueue
    
    public required init(socket: GenericSocket, onClose: ClientStateCallback?) {
        self.socket = socket
        self.rwq    = DispatchQueue.global(qos: .default)
        
        self.rwq.async {[unowned self] in
            var shouldKeepRunning = true
            var readData = Data(capacity: PupilServer.bufferSize)
            do {
                repeat {
                    let bytesRead = try self.socket.read(into: &readData)
                    if bytesRead > 0 {
                        
                    } else {
                        if self.socket.remoteConnectionClosed {
                            shouldKeepRunning = false
                            onClose?(self)
                            break
                        }
                    }
                } while shouldKeepRunning
                
            } catch let err {
                print("ERROR reading from socket", err)
            }
        }
    }
}
