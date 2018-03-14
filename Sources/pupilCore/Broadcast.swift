import Foundation

public struct Broadcast: Codable {
    
    public var userID: String
    public var title: String?
    public var broadcastID: String
    public var status: String
    public var thumbnails: [String]?
    public var user: User?
    public var createdAt: UInt64?
        
    public mutating func add(thumbnail: String) {
        if var nails = self.thumbnails {
            nails.append(thumbnail)
            self.thumbnails = nails
        } else {
            self.thumbnails = [thumbnail]
        }
    }
    
}
