import Foundation

public enum SessionMode {
    case text
    case streaming
}

public protocol Session {
    init(socket: GenericSocket, delegate: SessionDelegate)
    var mode: SessionMode { get }
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

    public var hashValue: Int {
        if let c = self.client {
            return Int(c.socket.socketfd)
        }
        return -1
    }
    
    public required init(socket: GenericSocket,
                         delegate: SessionDelegate)
    {
        self.delegate = delegate
        self.mode     = .text
        self.client = PupilClient(socket: socket) { _ in
            self.delegate.disconnected(session: self)
        }
    }
    
}
