import Foundation
import Socket
import Dispatch
import morsel
import pupilCore

let port: Int32 = 40002
let server      = PupilServer(port: port, root: URL(fileURLWithPath: "/opt/broadcasts"))

do {

    try server.start() {
        print("pupil server running on port \(port)\n.o0[cabin in the woods]0o.\n\(version)")
    }

    dispatchMain()

} catch let err {
    print("Problem starting server:", err)
}

