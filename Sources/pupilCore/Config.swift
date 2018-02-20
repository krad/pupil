import Foundation
import HeliumLogger
import LoggerAPI

let AWS_REGION_KEY           = "AWS_REGION"
let AWS_KEYID_KEY            = "AWS_KEYID"
let AWS_KEYSECRET            = "AWS_KEYSECRET"
let PUPIL_PORT               = "PUPIL_PORT"
let PUPIL_ROOT               = "PUPIL_ROOT"
let PUPIL_BUCKET             = "PUPIL_BUCKET"
let PUPIL_THUMBNAIL_INTERVAL = "PUPIL_THUMBNAIL_INTERVAL"

internal var ENVIRONMENT = ProcessInfo.processInfo.environment

let ENV_KEYS = [AWS_REGION_KEY,
                AWS_KEYID_KEY,
                AWS_KEYSECRET,
                PUPIL_PORT,
                PUPIL_ROOT,
                PUPIL_BUCKET,
                PUPIL_THUMBNAIL_INTERVAL]

public enum ConfigError: Error {
    case fileNotFound
    case keyNotFound(key: String)
    case badKeyValue(key: String)
}

func configureLogger() {
    let logger     = HeliumLogger()
    logger.colored = true
    Log.logger     = logger
}

public struct Config {
    
    internal static var values: ConfigValues?

    static var port: Int32 {
        if let p = values?.port { return p }
        return 42000
    }
    
    static var root: URL {
        if let r = values?.root { return r }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }
    
    static var thumbnailInterval: Int {
        if let t = values?.thumbnailInterval { return t }
        return 30
    }
    
    static var bucket: String {
        if let b = values?.bucket { return b }
        return ""
    }
    
    public static func load(from file: URL) throws {
        self.values = try ConfigValues.load(from: file)
    }
    
    public static func loadFromEnvironment() throws {
        self.values = try ConfigValues.from(environment: ENVIRONMENT)
    }

}

public struct ConfigValues: Decodable {
    
    let port: Int32
    let root: URL
    let bucket: String
    let region: String
    let keyID: String
    let keySecret: String
    let thumbnailInterval: Int
    
    enum CodingKeys: String, CodingKey {
        case port               = "port"
        case root               = "root"
        case bucket             = "bucket"
        case region             = "region"
        case keyID              = "key_id"
        case keySecret          = "key_secret"
        case thumbnailInterval  = "thumbnail_interval"
    }
    
    internal static func load(from file: URL) throws -> ConfigValues {
        if FileManager.default.fileExists(atPath: file.path) {
            let configData = try Data(contentsOf: file)
            let config     = try JSONDecoder().decode(ConfigValues.self, from: configData)
            return config
        } else {
            throw ConfigError.fileNotFound
        }
    }
    
    internal static func from(environment: [String: String]) throws -> ConfigValues {
        var port: Int32 = 42000
        if let p = environment[PUPIL_PORT] {
            if let intp = Int32(p) { port = intp }
        }
        
        var root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        if let r = environment[PUPIL_ROOT] { root = URL(fileURLWithPath: r) }
        
        guard let bucket =
            environment[PUPIL_BUCKET] else { throw ConfigError.keyNotFound(key: PUPIL_BUCKET) }
        guard let region =
            environment[AWS_REGION_KEY] else { throw ConfigError.keyNotFound(key: AWS_REGION_KEY) }
        guard let key =
            environment[AWS_KEYID_KEY] else { throw ConfigError.keyNotFound(key: AWS_KEYID_KEY) }
        guard let secret =
            environment[AWS_KEYSECRET] else { throw ConfigError.keyNotFound(key: AWS_KEYSECRET)}
        
        var tInterval = 30
        if let thumb = environment[PUPIL_THUMBNAIL_INTERVAL] {
            if let t = Int(thumb) { tInterval = t }
        }
        
        let config = ConfigValues(port: port,
                                  root: root,
                                  bucket: bucket,
                                  region: region,
                                  keyID: key,
                                  keySecret: secret,
                                  thumbnailInterval: tInterval)
        
        return config
    }

}
