import XCTest
@testable import pupilCore
import grip

class AVSessionTests: XCTestCase {

    func test_basic_behavior_of_av_session() {
        let path            = URL(fileURLWithPath: NSTemporaryDirectory())
        let broadcastID     = UUID().uuidString
        let expectedPath    = path.appendingPathComponent(broadcastID)
        
        XCTAssertFalse(FileManager.default.fileExists(atPath: expectedPath.path))
        let session         = try? AVSession(broadcastID: broadcastID, root: path)
        XCTAssertNotNil(session)
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedPath.path))
        
        XCTAssertNil(session?.streamType)
        XCTAssertNil(session?.videoSettings)
        XCTAssertNil(session?.videoDimensions)
        XCTAssertNil(session?.videoParams)
        XCTAssertNil(session?.mediaWriter)
        
        /// Test sending a StreamTypePacket
        let streamType       = StreamType.video
        let streamTypePacket = StreamTypePacket(streamType: streamType)
        let streamTypeBytes  = try? BinaryEncoder.encode(streamTypePacket)
        XCTAssertNotNil(streamTypeBytes)
        session?.read(streamTypeBytes!)
        
        XCTAssertNotNil(session?.streamType)
        XCTAssertNotNil(session?.mediaWriter)
        
        /// Test sending a VideoParamSetPacket
        let paramsPacket = try? VideoParamSetPacket(params: [sps, pps])
        XCTAssertNotNil(paramsPacket)
        let paramsBytes  = try? BinaryEncoder.encode(paramsPacket!)
        XCTAssertNotNil(paramsBytes)
        session?.read(paramsBytes!)
        
        XCTAssertNotNil(session?.videoParams)
        
        /// Test sending a video dimensions packet
        let dimensionsPacket = VideoDimensionPacket(width: 640, height: 480)
        let dimensionBytes   = try? BinaryEncoder.encode(dimensionsPacket)
        XCTAssertNotNil(dimensionBytes)
        session?.read(dimensionBytes!)
        
        XCTAssertNotNil(session?.videoDimensions)
    }
    
}
