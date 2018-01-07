import Foundation
import SwiftAWSS3
import AWSSDKSwiftCore

let AWS_REGION_KEY = "AWS_REGION"
let AWS_KEYID_KEY  = "AWS_KEYID"
let AWS_KEYSECRET  = "AWS_KEYSECRET"

enum CloudManagerError: Error {
    case configInfoMissing
}

class CloudManager {
    
    private let client: S3
    private let bucket = "krad-tv-staging-video"
    
    private let sessionConfiguration = URLSessionConfiguration.default
    private let urlSession: URLSession
    
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
    
    func update(broadcast: String, with state: PupilSessionState) {
        print("Updating \(broadcast) state: \(state.rawValue)")
        let payload: [String: Any] = ["status": state.rawValue]
        
        do {
            if let url = URL(string: "https://staging.krad.tv/broadcasts/\(broadcast)") {
                let payloadData    = try JSONSerialization.data(withJSONObject: payload,
                                                                options: .prettyPrinted)
                var request        = URLRequest(url: url)
                request.httpMethod = "POST"
                request.httpBody   = payloadData
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.addValue("application/json", forHTTPHeaderField: "Accept")
                
                let task = self.urlSession.dataTask(with: request) {(data, resp, err) in }
                task.resume()
            }
            
        } catch let error {
            print("Couldn't update broadcast state: \(error.localizedDescription)")
        }
        
    }
    
    func upload(file atURL: URL, deleteAfterUpload: Bool) throws {
        var urlComponents = atURL.absoluteString.components(separatedBy: "/")
        let fileName      = urlComponents.popLast()!
        let broadcastID   = urlComponents.popLast()!
        let bucketKey     = "\(broadcastID)/\(fileName)"
        print("[UPLOAD] - Starting  - ", bucketKey)
        
        let data = try Data(contentsOf: atURL)
        var contentType = ""
        if fileName == "out.m3u8" { contentType = "application/x-mpegURL" }
        else { contentType = "video/mp4" }

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
        
        print("[UPLOAD] - Completed - ", bucketKey)
        
        if deleteAfterUpload {
            print("[CLEANUP] - Started   - ", atURL)
            try FileManager.default.removeItem(at: atURL)
            print("[CLEANUP] - Completed - ", atURL)
        }
    }

}
