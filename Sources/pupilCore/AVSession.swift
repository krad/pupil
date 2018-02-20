import Foundation
import morsel
import grip


/// Network front end for an audio/video session.
class AVSession {
    
    /// The broadcastID associated with the current session
    var broadcastID: String
    
    /// The directory that media files will be written to
    var broadcastRoot: URL
    
    /// The type of stream associated with the session (ex: video+audio, video only, audio only)
    var streamType: StreamType? {
        didSet {
            if let st = streamType {
                do { self.mediaWriter = try MediaWriter(streamType: st, outputDir: self.broadcastRoot) }
                catch let err { print("Coudln't setup media writer", err) }
            }
        }
    }
    
    /// The object which is responsible for writing out media assets and playlists
    var mediaWriter: MediaWriter?
    
    /// Settings used for video streams to configure the video writer
    var videoSettings: VideoSettings?
    
    /// When we have a video stream, these are the dimensions of the picture
    var videoDimensions: VideoDimensions?
    
    /// When we have a video stream this contains an array of btyes representing the Sequence Parameter set and the Picture Parameter set
    var videoParams: [[UInt8]]?
    
    /// An array of bytes from the stream.  Grows and shrinks based on what has / has not been processed
    var buffer: [UInt8] = []
    
    /// Initialize a new AVSession.  Used to handle the binary portion of a stream session
    ///
    /// - Parameters:
    ///   - broadcastID: broadcastID to associate the data with
    ///   - root: The root directory the AVSession should create a broadcast directory in
    /// - Throws: Throws is we can not access or create a directory for the broadcast
    init(broadcastID: String, root: URL) throws {
        self.broadcastID    = broadcastID
        self.broadcastRoot  = root.appendingPathComponent(broadcastID)
        try self.setupDirectory(for: broadcastID)
    }
    
    
    /// Reads packets from a session
    ///
    /// - Parameter data: Read bytes from an A/V stream.
    ///   Will buffer bytes until full packets or a/v data is found.
    ///
    func read( _ data: [UInt8]) {
        guard buffer(data: data),
        let length = self.getNextLength() else { return }
    
        let packetBytes = getPacketBytes(length: length)
        if let packetType = getPacketType(packet: packetBytes) {
            self.handle(packet: packetBytes, type: packetType)
            self.buffer.removeFirst(Int(length))
        } else if let sampleType = getSampleType(packet: packetBytes) {
            self.handle(sample: packetBytes, type: sampleType)
            self.buffer.removeFirst(Int(length))
        }
    }
    
    
    /// Used to buffer data read from a client
    ///
    /// - Parameter data: An array of 8 bit integers
    /// - Returns: Returns true if we successfully buffered the data
    private func buffer(data: [UInt8]) -> Bool {
        if data.count > 0 {
            self.buffer.append(contentsOf: data)
            return true
        }
        return false
    }
    
    /// Packets received come prepended with 4 bytes describing the length until the next packet
    ///
    /// - Returns: A unsigned 32bit integer
    private func getNextLength() -> UInt32? {
        let lengthBytes = Array(self.buffer[0..<4])
        if let length = UInt32(bytes: lengthBytes) {
            if length > self.buffer.count { return nil }
            else { return length }
        }
        return nil
    }
    
    
    /// Gets the actual packet payload AFTER the first 4 length bytes
    ///
    /// - Parameter length: The length of the packet
    /// - Returns: An array of unsigned 8 bit integers WITHOUT their length data
    private func getPacketBytes(length: UInt32) -> [UInt8] {
        let packetBytes = self.buffer[4..<Int(length)]
        return Array(packetBytes)
    }
    
    
    /// After the length data, packets have a 1 byte (8 bit) flag used to describe the type of packet
    ///
    /// - Parameter packet: A packet payload (bytes starting AFTER the length data)
    /// - Returns: A PacketType enum with the correct type selected
    private func getPacketType(packet: [UInt8]) -> PacketType? {
        let typeByte = packet[0]
        return PacketType(rawValue: typeByte)
    }
    
    
    /// The same thing as a packet, but contains either audio or video types
    ///
    /// - Parameter packet: A packet payload (bytes starting AFTER the length data)
    /// - Returns: A SampleType enum with the correct type selected
    private func getSampleType(packet: [UInt8]) -> SampleType? {
        let typeByte = packet[0]
        return SampleType(rawValue: typeByte)
    }
    
    
    /// Handles message / config packets.  We can receive packets that configure the stream.
    /// This is where we handle them.
    ///
    /// - Parameters:
    ///   - packet: An array of integers representing an entire packet starting AFTER it's length data
    ///   - type: An enum describing the type of packet being dealt with
    private func handle(packet: [UInt8], type: PacketType) {
        switch type {
        case .streamType:      self.streamType      = StreamType.parse(packet)
        case .videoDimensions: self.videoDimensions = VideoDimensions(from: packet)
        case .videoParams:     self.videoParams     = packet.split(separator: type.rawValue).map { Array($0) }
        }
    }
    
    
    /// Handles audio / video sample packets.
    ///
    /// - Parameters:
    ///   - sample: Sample bytes representing an Audio / Video sample
    ///   - type: An enum flagging the type of sample in the bytes payload
    private func handle(sample: [UInt8], type: SampleType) {
        switch type {
        case .video: self.mediaWriter?.handle(video: sample)
        case .audio: self.mediaWriter?.handle(audio: sample)
        }
    }
    
    
    /// Create the broadcast directory if it does not exist
    ///
    /// - Parameter broadcastID: the broadcastID associated with the session
    /// - Throws: Throws if we can not create / write to the directory
    private func setupDirectory(for broadcastID: String) throws {
        if !FileManager.default.fileExists(atPath: self.broadcastRoot.path) {
            try FileManager.default.createDirectory(at: self.broadcastRoot,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)
        }
    }
    
}
