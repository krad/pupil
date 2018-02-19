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

class PupilSession {
    
    var state: PupilSessionState {
        didSet {
            guard let broadcastID = self.broadcastID else { return }
            self.cloudManager.setup(with: broadcastID)
            self.cloudManager.update(broadcast: broadcastID, with: self.state)
        }
    }
    
    private var socket: Socket
    private var root: URL
    private var buffer: [UInt8] = []
    
    private var params: [[UInt8]]?
    private var videoSettings: VideoSettings?
    private var dimensions: VideoDimensions?
    
    private var writer: FragmentedMP4Writer?
    private var streamType: StreamType?
    
    private var memento: Memento?
    private var mementoKeyframeCnt = 0
    
    fileprivate var cloudManager: CloudManager
    fileprivate var uploadedFileCallback: (() -> Void)?
    
    var broadcastID: String? {
        didSet {
            if let bid = broadcastID {
                print("[SETUP] - GOT BROADCAST ID - STREAM STARTING - ", bid)
                self.state = .streaming
                self.setupThumbnailer()
            }
        }
    }
    
    /// FIXME: Queue name needs to be unique for multiple sessions
    fileprivate let sessionQueue = DispatchQueue(label: "session.q",
                                                 qos: .userInitiated,
                                                 attributes: .concurrent,
                                                 autoreleaseFrequency: .inherit,
                                                 target: nil)
    
    
    init(socket: Socket, root: URL) throws {
        self.socket         = socket
        self.root           = root
        self.state          = .starting
        self.cloudManager   = try CloudManager()
    }
    
    func read(into data: inout Data) throws -> Int {
        return try self.socket.read(into: &data)
    }
    
    func read(bytes: [UInt8]) {
        guard bytes.count > 0 else { return }
        self.buffer.append(contentsOf: bytes)
        
        let lengthBytes = Array(self.buffer[0..<4])
        if let length = UInt32(bytes: lengthBytes) {
            
            if length > self.buffer.count { return }
            else {
                let packet   = self.buffer[4..<Int(length)]
                let typeByte = packet[4]
                
                if let sampleType = SampleType(rawValue: typeByte) {
                    switch sampleType {
                    case .video: self.handleVideoPacket(Array(packet))
                    case .audio: self.handleAudioPacket(Array(packet))
                    }
                } else {
                    
                    switch typeByte {
                    case 0x70:
                        // Got a params (sps/pps) packet
                        print("Got sps/pps packet", packet)
                        self.params = packet.split(separator: 0x70).map { Array($0) }
                        print("Setting params as", self.params as [[UInt8]]!)
                    case 0x71:
                        // Got a video dimensions packet
                        print("Got video dimensions packet")
                        let dimensions = VideoDimensions(from: Array(packet))
                        self.dimensions = dimensions
                        print(dimensions)
                    case 0x72:
                        // Got a stream type packet (are we audio+video, video only, audio only, etc)
                        print("Got stream type packet")
                        if let streamType = StreamType.parse(Array(packet)) {
                            self.streamType = streamType
                            self.setupWriter(streamType: streamType)
                        }
                    default: print("Received unrecognized packet type:", typeByte)
                    }
                    
                }
                
                self.buffer.removeFirst(Int(length))
            }
        }
    }
    
    func write(response: String) throws -> Int {
        if let data = response.data(using: .utf8) { return try self.socket.write(from: data) }
        return -1
    }
    
    private func handleVideoPacket(_ packet: [UInt8]) {
        let sample = VideoSample(bytes: packet)

        if sample.isSync {
            if self.mementoKeyframeCnt == 5 {
                if let sps = self.params?.first {
                    if let pps = self.params?.last {
                        
                        // FIXME: Figure out wtf Apple is doing with their SPS/PPS info
                        self.memento?.set(sps: Array(sps[1..<sps.count]),
                                          pps: Array(pps[1..<pps.count]))
                        
                        for nalu in sample.nalus {
                            self.memento?.decode(keyframe: Array(nalu.data[4..<nalu.data.count]))
                        }
                        
                        self.mementoKeyframeCnt = 0
                    }
                }
                
            } else {
                self.mementoKeyframeCnt += 1
            }
        }
        
        if let params = self.params {
            if let dimensions = self.dimensions {
                
                if let writer = self.writer {
                    
                    let settings = VideoSettings(params: params,
                                                 dimensions: dimensions,
                                                 timescale: sample.timescale)
                    
                    // Compare settings with last settings
                    if let prevSettings = self.videoSettings {
                        if prevSettings != settings {
                            writer.configure(settings: settings)
                            self.videoSettings = settings
                        }
                    } else {
                        self.videoSettings = settings
                        writer.configure(settings: settings)
                    }
                    
                    writer.append(sample: sample, type: sample.type)
                }
            }
        }
    }
    
    private func handleAudioPacket(_ packet: [UInt8]) {
        let sample  = AudioSample(bytes: packet)
        let settings = AudioSettings(sample)
        if let writer = self.writer {
            writer.configure(settings: settings)
            writer.append(sample: sample, type: sample.type)
        }
    }
    
    private func setupThumbnailer() {
        guard let broadcastID = self.broadcastID else { return }
        let thumbnailStorageURL = self.root.appendingPathComponent(broadcastID)
        self.memento = Memento(outputDir: thumbnailStorageURL, delegate : self)
    }
    
    private func setupWriter(streamType: StreamType) {
        guard let broadcastID = self.broadcastID else { return }
        do {
            let streamStorageURL = self.root.appendingPathComponent(broadcastID)
            try FileManager.default.createDirectory(at: streamStorageURL,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)
            
            print("Setting up writer...")
            self.writer = try FragmentedMP4Writer(streamStorageURL,
                                                  targetDuration: 6.0,
                                                  streamType: streamType,
                                                  delegate: self)
            
            do {
                
                print("Creating playlists...")
                let vodPlaylist     = Playlist(type: .hls_vod, fileName: "vod.m3u8")
                let eventPlaylist   = Playlist(type: .hls_event, fileName: "event.m3u8")
                let livePlaylist    = Playlist(type: .hls_live, fileName: "live.m3u8")
                
                try self.writer?.add(playlist: vodPlaylist)
                try self.writer?.add(playlist: eventPlaylist)
                try self.writer?.add(playlist: livePlaylist)
                
            } catch let error {
                print("Error configuring playlist:", error)
            }
            
        }
        catch let error { print("Could not setup mp4 writer", error.localizedDescription) }
        
        print("Writer configured.")
    }
    
    func close(onComplete: @escaping (Socket) -> Void) {
        self.socket.close()
        self.writer?.stop()
        self.uploadedFileCallback = { onComplete(self.socket) }
        self.state = .done
    }
    
}

extension PupilSession: FileWriterDelegate {
    
    func wroteFile(at url: URL) {
        print(#function, url)
        self.sessionQueue.async {
            do {
                try self.cloudManager.upload(file: url, deleteAfterUpload: true)
                self.uploadedFileCallback?()
            } catch let error {
                print("[ERROR] - Couldn't upload file:", error)
                print("[RETRY] - ", url)
                self.wroteFile(at: url)
            }
        }
    }
    
    func updatedFile(at url: URL) {
        print(#function, url)
        self.sessionQueue.async {
            do {
                try self.cloudManager.upload(file: url, deleteAfterUpload: false)
                self.uploadedFileCallback?()
            } catch let error {
                print("[ERROR] - Couldn't upload file:", error)
                print("[RETRY] - ", url)
                self.updatedFile(at: url)
            }
        }
    }
    
}

extension PupilSession: MementoProtocol {
    
    func wroteJPEG(to url: URL) {
        print(#function, url)
        self.sessionQueue.async {
            do {
                try self.cloudManager.upload(file: url, deleteAfterUpload: true)
                self.uploadedFileCallback?()
            } catch let error {
                print("[ERROR] - Couldn't upload file:", error)
                print("[RETRY] - ", url)
                self.wroteJPEG(to: url)
            }
        }
    }
    
    func failedToWriteJPEG(error: Error) {
        print("Couldn't write jpeg", error)
    }
}
