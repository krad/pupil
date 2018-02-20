import Foundation
import morsel
import memento
import grip

class MediaWriter {
    
    private var mediawriter: FragmentedMP4Writer?
    private var thumbnailWriter: Memento?
    
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
    
    func handle(video packet: [UInt8]) {
        let sample = VideoSample(bytes: packet)
        if let writer = self.mediawriter {
            writer.append(sample: sample, type: .video)
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
    
}

extension MediaWriter: FileWriterDelegate {
    func wroteFile(at url: URL) {
        
    }
    
    func updatedFile(at url: URL) {
        
    }
}

extension MediaWriter: MementoProtocol {
    func wroteJPEG(to url: URL) {
        
    }
    
    func failedToWriteJPEG(error: Error) {
        
    }
}
