import XCTest
@testable import pupilCore

class pupilTests: XCTestCase {

    func test_that_we_can_encode_and_decode_broadcasts() {
        
        let jsonURL  = URL(fileURLWithPath: fixturesPath).appendingPathComponent("broadcast.json")
        let jsonData = try? Data(contentsOf: jsonURL)
        XCTAssertNotNil(jsonData)
        XCTAssertGreaterThan(jsonData!.count, 0)
        
        let jsonDecoder = JSONDecoder()
        var broadcast   = try? jsonDecoder.decode(Broadcast.self, from: jsonData!)
        XCTAssertNotNil(broadcast)
        
        XCTAssertEqual("almost victory.  need api.", broadcast?.title)
        XCTAssertEqual("DONE", broadcast?.status)
        XCTAssertEqual("990349bd-7c35-44d9-95e2-7b9c35a58b1a", broadcast?.broadcastID)
        XCTAssertEqual("9f0ed131-1f9e-48f4-a8e0-99ad2f19601a", broadcast?.userID)
        XCTAssertNil(broadcast?.thumbnails)
        
        broadcast?.add(thumbnail: "0.jpg")
        XCTAssertNotNil(broadcast?.thumbnails)
        
        broadcast?.add(thumbnail: "1.jpg")
        broadcast?.add(thumbnail: "2.jpg")
        broadcast?.add(thumbnail: "3.jpg")
        XCTAssertEqual(broadcast?.thumbnails?.count, 4)

        let jsonEncoder  = JSONEncoder()
        let modifiedJSON = try? jsonEncoder.encode(broadcast)
        XCTAssertNotNil(modifiedJSON)
        XCTAssertGreaterThan(modifiedJSON!.count, 0)
        
        let backBroadcast = try? jsonDecoder.decode(Broadcast.self, from: modifiedJSON!)
        XCTAssertNotNil(backBroadcast)
        XCTAssertNotNil(backBroadcast?.thumbnails)
        XCTAssertEqual(backBroadcast?.thumbnails?.count, 4)        
    }
    
}

