import Foundation
import morsel
import memento
import grip

class MediaWriter {
    
    private var mediawriter: FragmentedMP4Writer?
    private var thumbnailWriter: Memento?
    
    /// Settings used for video streams to configure the video writer
    var videoSettings: VideoSettings?
    
    /// When we have a video stream, these are the dimensions of the picture
    var videoDimensions: VideoDimensions?
    
    /// When we have a video stream this contains an array of btyes representing the Sequence Parameter set and the Picture Parameter set
    var videoParams: [[UInt8]]?

    
    init(streamType: StreamType, outputDir: URL) throws {
        self.mediawriter = try FragmentedMP4Writer(outputDir,
                                              targetDuration: 6.0,
                                              streamType: streamType,
                                              delegate: self)
        
        let vodPlaylist     = Playlist(type: .hls_vod, fileName: "vod.m3u8")
        let eventPlaylist   = Playlist(type: .hls_event, fileName: "event.m3u8")
        let livePlaylist    = Playlist(type: .hls_live, fileName: "live.m38u")
        
        try self.mediawriter?.add(playlist: vodPlaylist)
        try self.mediawriter?.add(playlist: eventPlaylist)
        try self.mediawriter?.add(playlist: livePlaylist)
        
        if streamType == .video {
            self.thumbnailWriter = Memento(outputDir: outputDir, delegate: self)
        }
    }
    
    func handle(audio packet: [UInt8]) {
        let sample   = AudioSample(bytes: packet)
        let settings = AudioSettings(sample)
        if let writer = self.mediawriter {
            writer.configure(settings: settings)
            writer.append(sample: sample, type: .audio)
        }
    }
    
    func handle(video packet: [UInt8]) {
        guard let writer = self.mediawriter else { return }
        let sample = VideoSample(bytes: packet)
        
        self.checkForVideoSettings(sample: sample)
        self.checkForVideoSettingChanges(sample: sample)
        self.digestForThumbnailProcessing(sample: sample)
        
        writer.append(sample: sample, type: .video)
    }
    
    private func checkForVideoSettings(sample: VideoSample) {
        guard let writer        = self.mediawriter,
              let dimensions    = self.videoDimensions,
              let params        = self.videoParams else { return }
        
        if self.videoSettings == nil {
            let settings = VideoSettings(params: params,
                                         dimensions: dimensions,
                                         timescale: sample.timescale)
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
        print("======", #function)
    }
    
    func updatedFile(at url: URL) {
        print("======", #function)
    }
}

extension MediaWriter: MementoProtocol {
    func wroteJPEG(to url: URL) {
        print("======", #function)
    }
    
    func failedToWriteJPEG(error: Error) {
        print("======", #function)
    }
}