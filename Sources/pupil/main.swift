import Foundation
import Socket
import Dispatch
import morsel
import pupilCore

let port    = 40002
let server  = PupilServer(port: port, root: URL(fileURLWithPath: "/opt/broadcasts"))

print("pupil server running\n.o0[shoey skills shack edition]0o.\n\(version)")
print("Connect with a command line window by telneting to port \(port)'")

server.run()
