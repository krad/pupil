import XCTest
@testable import pupilCore

class ClientTests: XCTestCase {
    
    class MockSocket: GenericSocket {
        var socketfd: Int32              = 0
        var remoteConnectionClosed: Bool = false
        var remoteHostname: String       = "SessionTests.tests"
        var remotePort: Int32            = 1024
        
        func read(into data: inout Data) throws -> Int { return 0 }
        func write(from data: Data) throws -> Int { return 0 }
        func close() { }
    }

    func test_that_we_throw_when_writing_bad_data() {
        let socket = MockSocket()
        let client = PupilClient(socket: socket, onClose: nil)
        XCTAssertThrowsError(try client.write(nil))
    }
    
}
