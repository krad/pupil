import Foundation
import SwiftAWSS3
import AWSSDKSwiftCore
import photon
import LoggerAPI

enum CloudManagerError: Error {
    case configInfoMissing
}

class CloudManager {
    
    var photon: Photon
    var broadcastID: String
    var broadcast: Broadcast?
    
    private let s3Client: S3
    private let bucket = Config.bucket
    
    init(broadcastID: String) {
        self.photon         = Photon(host: Config.apiHost)
        self.broadcastID    = broadcastID
        
        let reg       = Region(rawValue: Config.region)
        self.s3Client = S3(accessKeyId: Config.key,
                           secretAccessKey: Config.secret,
                           region: reg,
                           endpoint: nil)

        self.setup()
    }
    
    func setup() {
        Log.info("Fetching broadcast details for \(self.broadcastID)")
        let getBroadcast = GetBroadcast(self.broadcastID)
        self.photon.send(getBroadcast) { result in
            switch result {
            case .success(let broadcast):
                Log.info("Got broadcast details: \(self.broadcastID)")
                self.broadcast = broadcast
            case .failure(let error):
                 Log.error("Error getting broadcast details: \(error)")
            }
        }
    }
    
    func update(broadcast: Broadcast) {
        let updateBroadcast = UpdateBroadcast(broadcast)
        self.photon.send(updateBroadcast) { result in
            switch result {
            case .success(let v):
                Log.info("Successfully updated broadcast: \(v)")
            case .failure(let err):
                Log.error("Problem updating broadcast: \(err)")
            }
        }
    }
    
    func upload(file atURL: URL, deleteAfterUpload: Bool) throws {
        var urlComponents = atURL.absoluteString.components(separatedBy: "/")
        let fileName      = urlComponents.popLast()!
        let broadcastID   = urlComponents.popLast()!
        let bucketKey     = "\(broadcastID)/\(fileName)"
        var isThumbNail    = false
        print("[UPLOAD] - Starting   - ", bucketKey)

        let data = try Data(contentsOf: atURL)


        var contentType = ""
        if fileName.contains(substring: "m3u8") {
            contentType = "application/x-mpegURL"
        }

        if fileName.contains(substring: "mp4") {
            contentType = "video/mp4"
        }

        if fileName.contains(substring: "jpg") {
            contentType = "image/jpeg"
            self.broadcast?.add(thumbnail: fileName)
            isThumbNail  = true
        }

        let req = S3.PutObjectRequest(bucket: self.bucket,
                                      tagging: nil,
                                      contentDisposition: nil,
                                      sSEKMSKeyId: nil,
                                      grantReadACP: nil,
                                      sSECustomerAlgorithm: nil,
                                      contentLanguage: nil,
                                      contentEncoding: nil,
                                      contentLength: Int64(data.count),
                                      grantWriteACP: nil,
                                      key: bucketKey,
                                      websiteRedirectLocation: nil,
                                      body: data,
                                      sSECustomerKey: nil,
                                      contentMD5: nil,
                                      cacheControl: nil,
                                      requestPayer: nil,
                                      grantFullControl: nil,
                                      sSECustomerKeyMD5: nil,
                                      acl: .publicRead,
                                      metadata: nil,
                                      expires: nil,
                                      contentType: contentType,
                                      storageClass: nil,
                                      grantRead: nil,
                                      serverSideEncryption: nil)


        _ = try self.s3Client.putObject(req)
        Log.info("Upload complete: \(bucketKey)")
        if isThumbNail {
            if let broadcast = self.broadcast {
                self.update(broadcast: broadcast)
            }
        }

        if deleteAfterUpload {
            Log.info("Cleanup started - \(atURL)")
            try FileManager.default.removeItem(at: atURL)
            Log.info("Cleanup complete - \(atURL)")
        }
    }

}
