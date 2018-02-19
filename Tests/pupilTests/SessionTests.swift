import XCTest
@testable import pupilCore

class SessionTests: XCTestCase {
    
    class MockSocket: GenericSocket {
        var socketfd: Int32              = 0
        var remoteConnectionClosed: Bool = false
        var remoteHostname: String       = "SessionTests.tests"
        var remotePort: Int32            = 1024
        
        var writeExp: XCTestExpectation?
        var writeData: Data?
        
        var readData: Data?
        
        func read(into data: inout Data) throws -> Int {
            if let d = readData {
                data.append(d)
                readData = nil
                return d.count
            }
            return 0
        }
        
        func write(from data: Data) throws -> Int {
            self.writeData = data
            self.writeExp?.fulfill()
            return 0
        }
        
        func close() {
            
        }
    }
    
    class MockDelegate: SessionDelegate {
        func disconnected(session: Session) { }
    }

    func test_that_the_text_portion_of_session_initialization() {
        let socket      = MockSocket()
        let delegate    = MockDelegate()
        
        socket.writeExp = self.expectation(description: "Should get the 'HI' message")
        let session     = try? PSession(socket: socket, delegate: delegate)
        XCTAssertNotNil(session)
        XCTAssertEqual(session?.mode, .text)
        
        /// Session should immediately send the connect message
        self.wait(for: [socket.writeExp!], timeout: 1)
        XCTAssertNotNil(socket.writeData)
        
        let hiStr = String(data: socket.writeData!, encoding: .utf8)
        XCTAssertNotNil(hiStr)

        let hi    = ServerTextResponse(rawValue: hiStr!)
        XCTAssertNotNil(hi)
        XCTAssertEqual(hi, ServerTextResponse.connect)
        
        //// Should get a BEGIN message after sending a broadcast id
        socket.writeExp = self.expectation(description: "Should get the 'BEGIN' message")
        socket.readData = "fake-id-string".data(using: .utf8)
        self.wait(for: [socket.writeExp!], timeout: 1)
        XCTAssertNotNil(socket.writeData)
        
        let beginStr = String(data: socket.writeData!, encoding: .utf8)
        XCTAssertNotNil(beginStr)
        
        let begin    = ServerTextResponse(rawValue: beginStr!)
        XCTAssertNotNil(begin)
        XCTAssertEqual(begin, ServerTextResponse.begin)
        
        XCTAssertEqual(session?.mode, .streaming)

    }
    
}
