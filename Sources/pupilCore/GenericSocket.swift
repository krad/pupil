import Foundation
import Socket

public protocol GenericSocket {
    var socketfd: Int32 { get }
    var remoteConnectionClosed: Bool { get }
    var remoteHostname: String { get }
    var remotePort: Int32 { get }
    
    func read(into data: inout Data) throws -> Int
    func write(from data: Data) throws -> Int
}

extension Socket: GenericSocket { }
