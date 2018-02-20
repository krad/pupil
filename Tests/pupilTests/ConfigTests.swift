import XCTest
@testable import pupilCore

class ConfigTests: XCTestCase {

    let confPath  = URL(fileURLWithPath: fixturesPath).appendingPathComponent("example.conf")

    func test_that_we_can_load_config_info_from_a_file() {
        XCTAssertNotNil(confPath)
        XCTAssertNoThrow(try ConfigValues.load(from: confPath))

        let config = try? ConfigValues.load(from: confPath)
        XCTAssertNotNil(config)
        XCTAssertEqual(1025,            config?.port)
        XCTAssertEqual("/tmp",          config?.root.path)
        XCTAssertEqual("bucket-name",   config?.bucket)
        XCTAssertEqual("us-east-1",     config?.region)
        XCTAssertEqual("my-key",        config?.keyID)
        XCTAssertEqual("my-secret",     config?.keySecret)
        XCTAssertEqual(50,              config?.thumbnailInterval)
    }
    
    func test_that_we_can_load_config_info_from_env_variables() {
        ENVIRONMENT[AWS_REGION_KEY] = "east"
        ENVIRONMENT[AWS_KEYID_KEY]  = "keyid"
        ENVIRONMENT[AWS_KEYSECRET]  = "secret"
        ENVIRONMENT[PUPIL_PORT]     = "1024"
        ENVIRONMENT[PUPIL_ROOT]     = "/tmp"
        ENVIRONMENT[PUPIL_BUCKET]   = "my-bucket"
        ENVIRONMENT[PUPIL_API_HOST] = "krad.tv"

        
        XCTAssertNoThrow(try ConfigValues.from(environment: ENVIRONMENT))
        let config = try? ConfigValues.from(environment: ENVIRONMENT)
        XCTAssertNotNil(config)
        XCTAssertEqual(1024,        config?.port)
        XCTAssertEqual("/tmp",      config?.root.path)
        XCTAssertEqual("my-bucket", config?.bucket)
        XCTAssertEqual("east",      config?.region)
        XCTAssertEqual("keyid",     config?.keyID)
        XCTAssertEqual("secret",    config?.keySecret)
        XCTAssertEqual(30,          config?.thumbnailInterval)
    }
    
    func test_that_we_can_access_variables_from_a_global_object() {

        XCTAssertNotNil(Config.port)
        XCTAssertEqual(Config.port, 42000)
        
        XCTAssertNotNil(Config.root)
        XCTAssertNotEqual(Config.root.path, "/tmp")
        
        XCTAssertNotNil(Config.thumbnailInterval)
        XCTAssertEqual(Config.thumbnailInterval, 30)

        XCTAssertNoThrow(try Config.load(from: confPath))

        try? Config.load(from: confPath)
        
        XCTAssertNotNil(Config.port)
        XCTAssertEqual(1025, Config.port)
        XCTAssertEqual(Config.root.path, "/tmp")
        XCTAssertEqual(Config.bucket, "bucket-name")

    }
    
}
