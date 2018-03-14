import Foundation
import Socket
import Dispatch
import morsel
import pupilCore
import LoggerAPI

do {
    try Config.loadFromEnvironment()
} catch let err {
    Log.error("Environment variables not set: \(err)")
    exit(-1)
}

do {
    let server = PupilServer()

    try server.start() {
        Log.info("pupil \(Version.tag) running on port \(Config.port) o0[\(Version.name)]0o.")
    }

    dispatchMain()

} catch let err {
    Log.error("Problem starting server: \(err)")
}

