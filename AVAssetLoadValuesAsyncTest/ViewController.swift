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

class ViewController: UIViewController, AVAssetResourceLoaderDelegate, AVPlayerViewControllerDelegate {
    let assetLoaderQueue = DispatchQueue(label: "loader.queue", attributes: [])

    var avPlayer: AVPlayer? {
        get {
            return avPlayerViewController?.player
        }
    }
    var avPlayerItem: AVPlayerItem?
    var avPlayerViewController: AVPlayerViewController?
    var baseURL: String {
        return mediaURL.text ?? ""
    }
    let initialMessage = "\n\nProblem: When we are on iOS11 we are not getting the KVO notification on the AVPlayerItem with the failure condition after receiving a 403 from the server, we are receiving it on iOS10 or below.\n\nThis program:\n-Try to simulate the process of the DRM running locally, providing the stream to the player from localhost instead of the real encrypted origin\n- Contains a web server on localhost port 5555 that always returns a 403 to any request he receives (and keeping the connection open).\n- Provides a quick way to monitor calls to the loadValuesAsynchronously(forKeys:) (we have experienced problems with no receiving the callback too, but unable to replicate on this App)\n- Provides a quick way to monitor changes on the AVPlayerItem, method we are using to notify the user that an error has been arised\n\nTo replicate:\n1. Pick 'Localhost 403 URL'\n2. Pick on Try loadValuesAsynchronously\n3. Close the player that should open automatically\n4. Read the log box, on iOS11, we are not getting the KVO observer notification, but we are getting it correctly on iOS10 and below"
    var networkTask: URLSessionTask?
    var shouldWaitReturnValue: Bool {
        if Thread.isMainThread {
            return shouldWaitReturnValueSwitch.isOn
        } else {
            var buttonValue: Bool = false
            DispatchQueue.main.sync {
                 buttonValue = shouldWaitReturnValueSwitch.isOn
            }
            return buttonValue
        }
    }
    var webServer403: WebServer403?

    enum Urls:String {
        case ok = "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8"
        case ko = "http://127.0.0.1:5555"
    }
    
    deinit {
        removeAVPlayerItemObservers()
    }
    
    @IBOutlet weak var mediaURL: UITextField!
    @IBOutlet weak var logView: UITextView!
    @IBOutlet weak var shouldWaitReturnValueSwitch: UISwitch!
    
    @IBAction func clear(_ sender: UIButton) {
        clearAll()
    }
    
    @IBAction func fillWith200Page(_ sender: UIButton) {
        mediaURL.text = Urls.ok.rawValue
    }
    
    @IBAction func fillWith403Page(_ sender: UIButton) {
        mediaURL.text = Urls.ko.rawValue
    }
    
    @IBAction func tryNormalWebCall(_ sender: UIButton) {
        clearAll()
        guard let url = URL(string: self.baseURL) else {
            addLog(message: "Unable to retrieve, URL not valid")
            return
        }
        addLog(message: "Before the connection to \(url) by web task")
        networkTask = URLSession.shared.dataTask(with: url) { [weak self] (data, response, error) in
            DispatchQueue.main.async {
                guard let strongSelf = self else { return }
                strongSelf.addLog(message: "In the callback to \(url) by the web task")
                let body = String(data: data ?? Data(), encoding: String.Encoding.utf8)
                strongSelf.addLog(message: "HTTP Body: \(String(describing: body))")
                strongSelf.addLog(message: "HTTP Code Response: \(String(describing: response))")
                strongSelf.addLog(message: "HTTP Error: \(String(describing: error))")
            }
        }
        networkTask?.resume()
    }
    
    @IBAction func tryLoadValuesAsynchronouslyForKey(_ sender: Any) {
        clearAll()
        guard let mediaURL = URL(string: self.baseURL) else {
            addLog(message: "\(Date()) Invalid or empty URL, we can't continue")
            return
        }
        let avAsset:AVURLAsset = AVURLAsset(url: mediaURL)
        
        avAsset.resourceLoader.setDelegate(self, queue: DispatchQueue.main)
        
        var error : NSError?
        
        addLog(message: "Before loadValuesAsynchronously for \(mediaURL)")
        if avAsset.statusOfValue(forKey: AVPlayerKeys.playable, error: &error) == .loaded && avAsset.isPlayable {
            addLog(message: "Loaded and playable")
        }
        
        if true {
            avAsset.resourceLoader.setDelegate(self, queue: assetLoaderQueue)
        }
        
        avAsset.loadValuesAsynchronously(forKeys: [AVPlayerKeys.tracks, AVPlayerKeys.playable]) { [weak self] in
            DispatchQueue.main.async {
                if let strongSelf = self {
                    strongSelf.addLog(message:"We are in the callback!!!!")
                    let avPlayerItem = AVPlayerItem(asset: avAsset)
                    strongSelf.avPlayerItem = avPlayerItem
                    strongSelf.addObserver(for: avPlayerItem)
                    strongSelf.addLog(message: "AVPlayerItem initial status: \(String(describing: strongSelf.description(for: avPlayerItem.status)))")
                
                    let avPlayer = AVPlayer(playerItem: avPlayerItem)
                    let avPlayerViewController = AVPlayerViewController()
                    if #available(iOS 9.0, *) {
                        avPlayerViewController.delegate = self
                    } else {
                        // Fallback on earlier versions
                    }
                    strongSelf.avPlayerViewController = avPlayerViewController
                    avPlayerViewController.player = avPlayer
                    strongSelf.present(avPlayerViewController, animated: true, completion: {
                        avPlayer.play()
                    })
                }
            }
        }
    }
    
    @IBAction func viewManual(_ sender: UIButton) {
        clearLog()
        addLog(message: initialMessage)
    }
    
    override func viewDidLoad() {
        clearLog()
        let newWebServer403 = WebServer403()
        webServer403 = newWebServer403
        if newWebServer403.listen(port: 5555) {
            addLog(message: "Listening on port 5555")
        } else {
            addLog(message: "Error listening on port 5555")
        }
        super.viewDidLoad()
    }
    
    func addLog(message: String) {
        var preMessage = ""
        if self.logView.text != nil || self.logView.text == "" {
            preMessage = "\n"
        }
        print(message)
        self.logView.text = (self.logView.text ?? "") + preMessage + self.addTimeStamp(message: message)
    }
    
    func clearAll() {
        clearLog()
        
        clearAVEnvironment()
        clearNetworkEnvironment()
    }

    func clearLog() {
        self.logView.text = ""
        
    }
    
    func addTimeStamp(message: String) -> String {
        return "\(Date()) - \(message)"
    }
    
    func addObserver(for avPlayerItem: AVPlayerItem) {
        avPlayerItem.addObserver(self, forKeyPath: AVPlayerKeys.status, options: .new, context: nil)
    }
    
    func clearAVEnvironment() {
        if let avPlayerViewController = avPlayerViewController {
            avPlayerViewController.player = nil
            avPlayerViewController.willMove(toParentViewController: nil)
            avPlayerViewController.view.removeFromSuperview()
            avPlayerViewController.didMove(toParentViewController: nil)
        }
        avPlayerViewController = nil
        removeAVPlayerItemObservers()
        avPlayerItem = nil
    }
    
    func clearNetworkEnvironment() {
        guard let task = networkTask else { return }
        task.cancel()
        networkTask = nil
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
        let retVal = shouldWaitReturnValue
        DispatchQueue.main.async { [weak self] in
            self?.addLog(message: "ShouldWaitForLoadingRequestedResource returning \(retVal)")
        }
        return retVal
    }
}

// AVPlayerViewControllerDelegate
extension ViewController {
    func playerViewControllerDidStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        addLog(message: "playerViewControllerDidStartPictureInPicture")
    }

    func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        addLog(message: "playerViewControllerDidStopPictureInPicture")
    }
    
    func playerViewControllerWillStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        addLog(message: "playerViewControllerWillStopPictureInPicture")
    }
    
    func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        addLog(message: "playerViewControllerWillStartPictureInPicture")
    }
    
    func playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart(_ playerViewController: AVPlayerViewController) -> Bool {
        return false
    }
}
