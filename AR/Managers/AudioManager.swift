//
//  AudioManager.swift
//  The One
//
//  Created by ברק בן חור on 26/06/2022.
//

import UIKit
import AVFoundation

class AudioManager: NSObject {
    static let defualt = AudioManager()
    //PLayer
    var player: AVPlayer?


    //Player
    func setupPlayer(_ url: URL?) {
        guard let url = url else { return }
        
        player = AVPlayer(url: url)
    }
    
    func play()  {
        Task { [weak self] in
            guard let self, let duration : CMTime = try? await player?.currentItem?.asset.load(.duration) else { return }
            let seconds : Float64 = CMTimeGetSeconds(duration)
            let currentTime = self.stringFromTimeInterval(interval: seconds)
            
            let currentDuration : CMTime = player!.currentTime()
            let currentSeconds : Float64 = CMTimeGetSeconds(currentDuration)
            let current = self.stringFromTimeInterval(interval: currentSeconds)
            
            if current == currentTime {
                await player?.seek(to: .zero)
            }
            
            player?.play()
            player?.volume = 1.0
        }
    }
    
    private func stringFromTimeInterval(interval: TimeInterval) -> String {
        let interval = Int(interval)
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        let hours = (interval / 3600)
        return  String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

extension AudioManager: AVAudioRecorderDelegate {
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        
        print("AudioManager Finish Recording")
        
    }
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("Encoding Error", error?.localizedDescription ?? "")
    }
}

extension AudioManager: AVAudioPlayerDelegate {
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer,
                                     successfully flag: Bool) {
        player.stop()
        
        print("Finish Playing")
        
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer,
                                        error: Error?) {
        print(error?.localizedDescription ?? "")
    }
}

