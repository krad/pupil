import XCTest
@testable import pupilCore

class AVSessionTests: XCTestCase {

    func test_basic_behavior_of_av_session() {
        let path            = URL(fileURLWithPath: NSTemporaryDirectory())
        let broadcastID     = "test-broadcast"
        let expectedPath    = path.appendingPathComponent(broadcastID)
        
        XCTAssertFalse(FileManager.default.fileExists(atPath: expectedPath.path))
        let session         = try? AVSession(broadcastID: broadcastID, root: path)
        XCTAssertNotNil(session)
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedPath.path))
    }
    
}
