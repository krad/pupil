import Foundation
import SwiftAWSS3
import AWSSDKSwiftCore

enum CloudManagerError: Error {
    case configInfoMissing
}

class CloudManager {
    
    private let client: S3
    private let bucket = "krad-tv-staging-video"
    
    private let sessionConfiguration = URLSessionConfiguration.default
    private let urlSession: URLSession
    private var broadcast: Broadcast?
    
    init() throws {
        guard let region    = ProcessInfo.processInfo.environment[AWS_REGION_KEY],
              let keyID     = ProcessInfo.processInfo.environment[AWS_KEYID_KEY],
              let keySecret = ProcessInfo.processInfo.environment[AWS_KEYSECRET]
        else { throw CloudManagerError.configInfoMissing }
        
        let reg     = Region(rawValue: region)
        self.client = S3(accessKeyId: keyID,
                         secretAccessKey: keySecret,
                         region: reg,
                         endpoint: nil)
        
        self.urlSession = URLSession(configuration:sessionConfiguration, delegate: nil, delegateQueue: nil)
    }
    
    func setup(with broadcastID: String) {
        if let url = URL(string: "https://staging.krad.tv/broadcasts/\(broadcastID)") {
            var request        = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            print("[SETUP] - GETTING BROADCAST DATA")
            let task = self.urlSession.dataTask(with: request) {(data, resp, err) in
                if let respData = data {
                    do {
                        let decoder    = JSONDecoder()
                        self.broadcast = try decoder.decode(Broadcast.self, from: respData)
                        print("[SETUP] - SUCCESS")
                    } catch let err{
                        print("[SETUP] - ERROR - Couldn't get setup response from API", err)
                    }
                }
            }
            task.resume()
        }
    }
    
    func update(broadcast: String, with data: Data) {
        if let url = URL(string: "https://staging.krad.tv/broadcasts/\(broadcast)") {
            var request        = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody   = data
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            
            let task = self.urlSession.dataTask(with: request) {(data, resp, err) in }
            task.resume()
        }
    }
    
    private func update(broadcast: String, with payload: [String: Any]) {
        do {
            let payloadData = try JSONSerialization.data(withJSONObject: payload,
                                                         options: .prettyPrinted)
            self.update(broadcast: broadcast, with: payloadData)
        } catch let error {
            print("Couldn't update broadcast state: \(error.localizedDescription)")
        }
    }
    
//    func update(broadcast: String, with state: PupilSessionState) {
//        print("Updating \(broadcast) state: \(state.rawValue)")
//        let payload: [String: Any] = ["status": state.rawValue]
//        self.update(broadcast: broadcast, with: payload)
//    }
    
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
        
        
        _ = try self.client.putObject(req)
        print("[UPLOAD]  - Completed   - ", bucketKey)
        if isThumbNail { self.updateThumbnails() }
        
        if deleteAfterUpload {
            print("[CLEANUP] - Started   - ", atURL)
            try FileManager.default.removeItem(at: atURL)
            print("[CLEANUP] - Completed - ", atURL)
        }
    }
    
    func updateThumbnails() {
        guard let broadcast = self.broadcast else { return }
        do {
            let encoder     = JSONEncoder()
            let jsonData    = try encoder.encode(broadcast)
            self.update(broadcast: broadcast.broadcastID, with: jsonData)
        } catch let err {
            print("[ERROR] - Coudln't update thumbnails:", err)
        }
    }

}
