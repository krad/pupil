import Foundation
import Socket
import morsel
import memento
import Dispatch
import grip

enum PupilSessionState: String {
    case starting  = "STARTING"
    case streaming = "LIVE"
    case done      = "DONE"
}


//extension OldPupilSession: FileWriterDelegate {
//    
//    func wroteFile(at url: URL) {
//        print(#function, url)
//        self.sessionQueue.async {
//            do {
//                try self.cloudManager.upload(file: url, deleteAfterUpload: true)
//                self.uploadedFileCallback?()
//            } catch let error {
//                print("[ERROR] - Couldn't upload file:", error)
//                print("[RETRY] - ", url)
//                self.wroteFile(at: url)
//            }
//        }
//    }
//    
//    func updatedFile(at url: URL) {
//        print(#function, url)
//        self.sessionQueue.async {
//            do {
//                try self.cloudManager.upload(file: url, deleteAfterUpload: false)
//                self.uploadedFileCallback?()
//            } catch let error {
//                print("[ERROR] - Couldn't upload file:", error)
//                print("[RETRY] - ", url)
//                self.updatedFile(at: url)
//            }
//        }
//    }
//    
//}
//
//extension OldPupilSession: MementoProtocol {
//    
//    func wroteJPEG(to url: URL) {
//        print(#function, url)
//        self.sessionQueue.async {
//            do {
//                try self.cloudManager.upload(file: url, deleteAfterUpload: true)
//                self.uploadedFileCallback?()
//            } catch let error {
//                print("[ERROR] - Couldn't upload file:", error)
//                print("[RETRY] - ", url)
//                self.wroteJPEG(to: url)
//            }
//        }
//    }
//    
//    func failedToWriteJPEG(error: Error) {
//        print("Couldn't write jpeg", error)
//    }
//}

