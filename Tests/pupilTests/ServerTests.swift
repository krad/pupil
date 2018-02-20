import XCTest
@testable import pupilCore
import Socket

class ServerTests: XCTestCase {
    
    func test_that_we_can_either_set_a_root_or_one_is_determined_for_us() {
        let port: Int32  = 3333
        let path         = URL(fileURLWithPath: NSTemporaryDirectory())
        let server       = PupilServer(port: port, root: path)
        XCTAssertNotNil(server)
        
        XCTAssertEqual(server.port, port)
        XCTAssertEqual(server.root, path)
        
        let cwd     = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let server2 = PupilServer(port: port, root: nil)
        XCTAssertNotNil(server2)
        XCTAssertEqual(server2.port, port)
        XCTAssertEqual(server2.root, cwd)
    }
    
    func test_that_we_have_some_responses_we_can_use_in_the_text_portion_of_protocol() {
        let connect = ServerTextResponse.connect
        XCTAssertEqual("HI\n", connect.rawValue)
        
        let begin = ServerTextResponse.begin
        XCTAssertEqual("BEGIN\n", begin.rawValue)
    }
    
    func test_that_we_can_start_and_stop_the_server() {
        let server = PupilServer(port: 3331, root: nil)
        XCTAssertFalse(server.started)

        let e = self.expectation(description: "Connecting to a server")
        XCTAssertNoThrow(try server.start {
            e.fulfill()
        })
        self.wait(for: [e], timeout: 2)
        XCTAssertTrue(server.started)
        

        server.stop()
        XCTAssertFalse(server.started)
    }

    func test_that_we_can_connect_to_a_running_server() {
        
        let port: Int32 = 3332
        let server       = PupilServer(port: port, root: nil)
        
        let s = self.expectation(description: "Starting the server")
        XCTAssertNoThrow(try server.start {
            s.fulfill()
        })
        self.wait(for: [s], timeout: 1)
        
        let client = try? Socket.create()
        XCTAssertNotNil(client)
        
        XCTAssertNoThrow(try? client?.connect(to: "127.0.0.1", port: port, timeout: 1))
        XCTAssertTrue(client!.isConnected)
        
        let r = self.expectation(description: "Registering the session with the server")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertEqual(1, server.sessions.count)
            r.fulfill()
        }
        self.wait(for: [r], timeout: 2)
        
        let d = self.expectation(description: "Registering the disconnect from the server")
        client?.close()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertEqual(0, server.sessions.count)
            d.fulfill()
        }
        self.wait(for: [d], timeout: 2)

    }
    
}
