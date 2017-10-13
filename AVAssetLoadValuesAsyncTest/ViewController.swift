//
//  ViewController.swift
//  AVAssetLoadValuesAsyncTest
//
//  Created by Ruiz, Pablo (Developer) on 22/09/2017.
//  Copyright © 2017 BSKYB. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit

struct AVPlayerKeys {
    static let bufferEmpty = "playbackBufferEmpty"
    static let duration = "duration"
    static let error = "error"
    static let likelyToKeepUp = "playbackLikelyToKeepUp"
    static let playable = "playable"
    static let bufferFull = "playbackBufferFull"
    static let rate = "rate"
    static let status = "status"
    static let tracks = "tracks"
    static let timedMetadata = "timedMetadata"
}

class ViewController: UIViewController, AVAssetResourceLoaderDelegate {
    fileprivate let vgDrmAssetLoaderQueue = DispatchQueue(label: "drm.assetLoader.queue", attributes: [])

    var avPlayer: AVPlayer?
    var avPlayerItem: AVPlayerItem?
    var avPlayerViewController: AVPlayerViewController?
    
    enum Urls:String {
        case ok = "http://pau.fazerbcn.org/sky/200.php"
        case ko = "http://pau.fazerbcn.org/sky/403.php"
    }
    
    deinit {
        removeAVPlayerItemObservers()
    }
    
    @IBOutlet weak var mediaURL: UITextField!
    @IBOutlet weak var logView: UITextView!
    
    @IBAction func fillWith200Page(_ sender: Any) {
        self.mediaURL.text = Urls.ok.rawValue
    }
    
    @IBAction func fillWith403Page(_ sender: Any) {
        self.mediaURL.text = Urls.ko.rawValue
    }
    
    @IBAction func tryLoadValuesAsynchronouslyForKey(_ sender: Any) {
        clearEnvironment()
        
        guard let mediaURL = URL(string: self.mediaURL.text ?? "") else {
            self.logView.text = "\(Date()) Invalid or empty URL, we can't continue"
            return
        }
        let avAsset:AVURLAsset = AVURLAsset(url: mediaURL)
        
        avAsset.resourceLoader.setDelegate(self, queue: DispatchQueue.main)
        
        var error : NSError?
        
        logView.text = addTimeStamp(message: "Before loadValuesAsynchronously for \(mediaURL)")
        if avAsset.statusOfValue(forKey: AVPlayerKeys.playable, error: &error) == .loaded && avAsset.isPlayable {
            addLog(message: "Loaded and playable")
        }
        
        if true {
            avAsset.resourceLoader.setDelegate(self, queue: vgDrmAssetLoaderQueue)
        }
        
        avAsset.loadValuesAsynchronously(forKeys: [AVPlayerKeys.tracks, AVPlayerKeys.playable, AVPlayerKeys.duration]) { [weak self] in
            DispatchQueue.main.async {
                self?.addLog(message:"We are in the callback!!!!")
            }
        }
        let avPlayerItem = AVPlayerItem(asset: avAsset)
        self.avPlayerItem = avPlayerItem
        addLog(message: "AVPlayerItem initial status: \(description(for: avPlayerItem.status))")
        addObserver(for: avPlayerItem)
        
        avPlayer = AVPlayer(playerItem: avPlayerItem)
        avPlayerViewController = AVPlayerViewController()
        avPlayerViewController?.player = avPlayer
        avPlayer?.play()
    }
    
    func addLog(message: String) {
        var preMessage = ""
        if self.logView.text != nil || self.logView.text == "" {
            preMessage = "\n"
        }
        self.logView.text = (self.logView.text ?? "") + preMessage + self.addTimeStamp(message: message)
    }
    
    func addTimeStamp(message: String) -> String {
        return "\(Date()) - \(message)"
    }
    
    func addObserver(for avPlayerItem: AVPlayerItem) {
        avPlayerItem.addObserver(self, forKeyPath: AVPlayerKeys.status, options: .new, context: nil)
    }
    
    func clearEnvironment() {
        avPlayer = nil
        avPlayerViewController = nil
        removeAVPlayerItemObservers()
        avPlayerItem = nil
    }
    
    func removeAVPlayerItemObservers() {
        if let avPlayerItem = self.avPlayerItem {
            removeObservers(for: avPlayerItem)
        }
    }
    
    func removeObservers(for avPlayerItem: AVPlayerItem) {
        avPlayerItem.removeObserver(self, forKeyPath: AVPlayerKeys.status)
    }
    
    func description(for status: AVPlayerItemStatus) -> String {
        switch status {
            case .failed:
                return "AVPlayerItemStatusFailed"
            case .readyToPlay:
                return "AVPlayerItemStatusReadyToPlay"
            case .unknown:
                return "AVPlayerItemStatusUnknown"
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == AVPlayerKeys.status {
            if let avPlayerItem = self.avPlayerItem {
                let status = description(for: avPlayerItem.status)
                addLog(message: "Current status: \(status)" )
            }
            addLog(message: "PlayerItem status changes, changes: \(String(describing: change))")
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
}

// AVAssetResourceLoaderDelegate
extension ViewController {
    
    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        let retVal = false
        print("ShouldWaitForLoadingRequestedResource returning \(retVal)")
        return retVal
    }
}
