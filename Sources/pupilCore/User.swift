import Foundation

public struct User: Codable {
    
    public var userID: String
    public var username: String?
    public var firstName: String?
    public var lastName: String?
    public var createdAt: Date?
    
}
