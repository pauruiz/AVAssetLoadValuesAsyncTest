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
    let initialMessage = "\n\nThe problem:\nWhen we are on iOS11 we are facing two problems after receiving a 403 from the media server (Cisco DRM on localhost) that we are not having on iOS 10 or lower:\n - We are not getting the callback for the loadValuesAsynchronouslyForKeys if we ask for duration of the AVAsset (not a big issue, as the duration is not needed till it is playable, but we should always get a completion call, and by that time, we know that the duration will be 0 as we are never going to be able to play anything)\n - We are not getting the KVO notification on the AVPlayerItem with the failure condition ever (on iOS 11).\n\nThis program:\n - Tries to simulate the process of the Cisco DRM running locally, providing the stream to the player from localhost instead of the real encrypted origin\n - Contains a web server on localhost port 5555 that always returns a 403 to any request he receives (keeping the connection open).\n - Provides some logs to monitor the calls to the loadValuesAsynchronouslyForKeys(forKeys:)\n - Provides some logs to monitor changes on the AVPlayerItem status, KVO we are using to notify the user that an error has been detected and closing the player\n\nTo replicate:\n1. Pick 'Localhost 403 URL'\n2. Pick on Try loadValuesAsynchronouslyForKeys\n3. Close the player that should open automatically\n4. Read the log box, on iOS11, we are not getting the KVO observer notification, but we are getting it correctly on iOS10 and below.\n5. Repeat the process asking for the duration, and now on the logs we should not receive the initial callback for the completion of the loadValuesAsynchronouslyForKeys (that we are receiving on iOS 10 or below)."
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
        case ko = "http://127.0.0.1:5555/trans/CHAN%3Alocator%3A5%3A3%3A7D2/profileAnExample.ts/hn_vod.m3u8?is_manifest=1"
    }
    
    deinit {
        removeAVPlayerItemObservers()
    }
    
    @IBOutlet weak var mediaURL: UITextField!
    @IBOutlet weak var logView: UITextView!
    @IBOutlet weak var shouldAskForDuration: UISwitch!
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
    
    @IBAction func shouldAskForDurationChanged(_ sender: UISwitch) {
        if sender.isOn {
            addLog(message: "We are going to ask for duration, iOS 11 will not come back after asking for Keys asynchronously (completion never called)")
        } else {
            addLog(message: "We are not going to ask for duration, completion block for loadingKeys Asynchronously will always be called (fine) (please check the bug about the AVPlayerItem status not set on iOS 11)")
        }
    }
    
    @IBAction func shouldWaitForLoadingOfRequestedResourceReturnedValueChanged(_ sender: UISwitch) {
        if sender.isOn {
            addLog(message: "We will ask to wait, so expect delays to receive a callback (we are waiting so everything is fine)")
        } else {
            addLog(message: "We will not ask to wait, so ALL iOS version will be fine on that (please check the bug when asking for duration too)")
        }
    }
    
    @IBAction func tryNormalWebCall(_ sender: UIButton) {
        clearAll()
        showDeviceInfo()
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
        showDeviceInfo()
        guard let mediaURL = URL(string: self.baseURL) else {
            addLog(message: "\(Date()) Invalid or empty URL, we can't continue")
            return
        }
        let avAsset:AVURLAsset = AVURLAsset(url: mediaURL)
        
        addLog(message: "Before loadValuesAsynchronously for \(mediaURL)")
        
        avAsset.resourceLoader.setDelegate(self, queue: assetLoaderQueue)
        
        var keysToAskFor = [AVPlayerKeys.tracks, AVPlayerKeys.playable];
        
        if shouldAskForDuration.isOn {
            keysToAskFor.append(AVPlayerKeys.duration);
        }
        
        avAsset.loadValuesAsynchronously(forKeys: keysToAskFor) { [weak self] in
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
    
    func showDeviceInfo(){
        addLog(message: "System version: \(UIDevice.current.systemVersion)")
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
