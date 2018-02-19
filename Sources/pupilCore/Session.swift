import Foundation

public enum SessionMode {
    case text
    case streaming
}

public protocol Session {
    init(socket: GenericSocket, delegate: SessionDelegate) throws
    var mode: SessionMode { get }
    var broadcastID: String? { get }
    
    var hashValue: Int { get }
}

public protocol SessionDelegate {
    func disconnected(session: Session)
}

func ==(lhs: Session, rhs: Session) -> Bool {
    return lhs.hashValue == rhs.hashValue
}


/// PupilSession - Represents
public class PSession: Session {
    private var client: Client?
    private let delegate: SessionDelegate
    
    public var mode: SessionMode
    public var broadcastID: String?

    public var hashValue: Int {
        if let c = self.client {
            return Int(c.socket.socketfd)
        }
        return -1
    }
    
    public required init(socket: GenericSocket,
                         delegate: SessionDelegate) throws
    {
        self.delegate = delegate
        self.mode     = .text
        self.client   = PupilClient(socket: socket) { _ in
            self.delegate.disconnected(session: self)
        }
        self.client?.onRead = self.read
        _ = try self.client?.write(ServerTextResponse.connect.rawValue)
    }
    
    func read(client: Client, data: Data) throws {
        switch self.mode {
        case .text:
            try self.handle(text: data)
        case .streaming:
            _=0+0
        }
    }
    
    func handle(text data: Data) throws {
        if let response = String(data: data, encoding: .utf8) {
            self.broadcastID = response.replacingOccurrences(of: "\n",
                                                           with: "",
                                                        options: .regularExpression,
                                                          range: nil)
            
            _ = try self.client?.write(ServerTextResponse.begin.rawValue)
        }
    }
    
    
    
}
