import Foundation

class AVSession {
    
    var broadcastID: String
    var broadcastRoot: URL
    
    init(broadcastID: String, root: URL) throws {
        self.broadcastID    = broadcastID
        self.broadcastRoot  = root.appendingPathComponent(broadcastID)
        if !FileManager.default.fileExists(atPath: self.broadcastRoot.path) {
            try FileManager.default.createDirectory(at: self.broadcastRoot, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    func read( _ data: [UInt8]) {
        
    }
    
}
