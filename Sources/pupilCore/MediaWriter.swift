import Foundation
import morsel
import memento
import grip
import photon
import LoggerAPI

enum SessionState: String {
    case starting   = "STARTING"
    case streaming  = "LIVE"
    case done       = "DONE"
}

class MediaWriter {
    
    private var mediawriter: FragmentedMP4Writer?
    private var thumbnailWriter: Memento?
    
    /// Settings used for video streams to configure the video writer
    var videoSettings: VideoSettings?
    
    /// When we have a video stream, these are the dimensions of the picture
    var videoDimensions: VideoDimensions?
    
    /// When we have a video stream this contains an array of btyes representing the Sequence Parameter set and the Picture Parameter set
    var videoParams: [[UInt8]]?
    
    /// This is the broadcastID associated with the media writer
    let broadcastID: String

    /// Writing big chunks of media can block the mp4 writer.
    /// We append async here to prevent that.
    fileprivate let mediaQ: DispatchQueue
    
    /// Syncing to the cloud can block.
    /// We make async dispatch's using this queue.
    fileprivate let cloudQ: DispatchQueue
    
    fileprivate var cloud: CloudManager?
    
    init(streamType: StreamType,
         broadcastID: String,
         outputDir: URL) throws
    {
        self.broadcastID = broadcastID
        self.mediaQ      = DispatchQueue(label: "\(broadcastID).media.q",
                                           qos: .default,
                                    attributes: DispatchQueue.Attributes(rawValue: 0),
                          autoreleaseFrequency: .inherit,
                                        target: nil)
        
        self.cloudQ      = DispatchQueue(label: "\(broadcastID).cloud.q",
                                           qos: .default,
                                    attributes: DispatchQueue.Attributes(rawValue: 0),
                          autoreleaseFrequency: .inherit,
                                        target: nil)

        self.mediawriter = try FragmentedMP4Writer(outputDir,
                                              targetDuration: 6.0,
                                              streamType: streamType,
                                              delegate: self)
        
        let vodPlaylist     = Playlist(type: .hls_vod, fileName: "vod.m3u8")
        let eventPlaylist   = Playlist(type: .hls_event, fileName: "event.m3u8")
        let livePlaylist    = Playlist(type: .hls_live, fileName: "live.m3u8")
        
        try self.mediawriter?.add(playlist: vodPlaylist)
        try self.mediawriter?.add(playlist: eventPlaylist)
        try self.mediawriter?.add(playlist: livePlaylist)
        
        if streamType.contains(.video) {
            self.thumbnailWriter = Memento(outputDir: outputDir, delegate: self)
        }
        
        self.cloud = CloudManager(broadcastID: self.broadcastID)
    }
    
    func handle(audio packet: [UInt8]) {
        self.mediaQ.async {
            let sample   = AudioSample(bytes: packet)
            let settings = AudioSettings(sample)
            if let writer = self.mediawriter {
                writer.configure(settings: settings)
                writer.append(sample: sample, type: .audio)
            }
        }
    }
    
    func handle(video packet: [UInt8]) {
        guard let writer = self.mediawriter else { return }
        self.mediaQ.async {
            let sample = VideoSample(bytes: packet)
            
            self.checkForVideoSettings(sample: sample)
            self.checkForVideoSettingChanges(sample: sample)
            self.digestForThumbnailProcessing(sample: sample)
            
            writer.append(sample: sample, type: .video)
        }
    }
    
    private func checkForVideoSettings(sample: VideoSample) {
        guard let writer        = self.mediawriter,
              let dimensions    = self.videoDimensions,
              let params        = self.videoParams else { return }
        
        if self.videoSettings == nil {
            let settings = VideoSettings(params: params,
                                         dimensions: dimensions,
                                         timescale: sample.timescale)
            self.videoSettings = settings
            writer.configure(settings: settings)
        }
    }
    
    private func checkForVideoSettingChanges(sample: VideoSample) {
        guard let writer       = self.mediawriter,
              let dimensions   = self.videoDimensions,
              let prevSettings = self.videoSettings,
              let params       = self.videoParams else { return }
        
        let settings = VideoSettings(params: params,
                                     dimensions: dimensions,
                                     timescale: sample.timescale)
        
        if prevSettings != settings {
            Log.info("Updating video settings")
            writer.configure(settings: settings)
            self.videoSettings = settings
        }
    }
    
    private func digestForThumbnailProcessing(sample: VideoSample) {
        guard sample.isSync else { return }
        if let sps = self.videoParams?.first {
            if let pps = self.videoParams?.last {
                self.thumbnailWriter?.set(sps: Array(sps[1..<sps.count]),
                                          pps: Array(pps[1..<pps.count]))
                
                for nalu in sample.nalus {
                    self.thumbnailWriter?.decode(keyframe: Array(nalu.data[4..<nalu.data.count]))
                }
            }
        }
    }

}

extension MediaWriter: FileWriterDelegate {
    func wroteFile(at url: URL) {
        Log.info("\(self.broadcastID) - wrote file: \(url.path)")
        self.cloudQ.async {
            do {
                try self.cloud?.upload(file: url, deleteAfterUpload: true)
            } catch let error {
                Log.error("Could NOT upload file: \(error)")
                self.wroteFile(at: url)
            }
        }
    }
    
    func updatedFile(at url: URL) {
        Log.info("\(self.broadcastID) - updated file: \(url.path)")
        self.cloudQ.async {
            do {
                try self.cloud?.upload(file: url, deleteAfterUpload: false)
            } catch let error {
                Log.error("Could NOT upload file: \(error)")
                self.updatedFile(at: url)
            }
        }
    }
}

extension MediaWriter: MementoProtocol {
    func wroteJPEG(to url: URL) {
        Log.info("\(self.broadcastID) - wrote jpeg: \(url.path)")
        self.cloudQ.async {
            do {
                try self.cloud?.upload(file: url, deleteAfterUpload: true)
            } catch let error {
                Log.error("Could NOT upload file: \(error)")
                self.wroteJPEG(to: url)
            }
        }
    }
    
    func failedToWriteJPEG(error: Error) {
        Log.error("\(self.broadcastID) - failed to write file: \(error)")
    }
}
