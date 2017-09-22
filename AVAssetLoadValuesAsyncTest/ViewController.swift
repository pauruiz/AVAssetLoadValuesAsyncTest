//
//  ViewController.swift
//  AVAssetLoadValuesAsyncTest
//
//  Created by Ruiz, Pablo (Developer) on 22/09/2017.
//  Copyright © 2017 BSKYB. All rights reserved.
//

import UIKit
import AVFoundation

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

class ViewController: UIViewController {

    enum Urls:String {
        case ok = "http://pau.fazerbcn.org/200.php"
        case ko = "http://pau.fazerbcn.org/403.php"
    }
    
    @IBOutlet weak var mediaURL: UITextField!
    @IBOutlet weak var logView: UITextView!
    
    @IBAction func fillWith200Page(_ sender: Any) {
        self.mediaURL.text = Urls.ok.rawValue
    }
    
    @IBAction func fillWith403Page(_ sender: Any) {
        self.mediaURL.text = Urls.ko.rawValue
    }
    
    @IBAction func tryLoadValuesAsynchronouslyForMedia(_ sender: Any) {
        guard let mediaURL = URL(string: self.mediaURL.text ?? "") else {
            self.logView.text = "\(Date()) Invalid or empty URL, we can't continue"
            return
        }
        let avAsset:AVURLAsset = AVURLAsset(url: mediaURL)
        
        var error : NSError?
        
        if avAsset.statusOfValue(forKey: AVPlayerKeys.playable, error: &error) == .loaded && avAsset.isPlayable {
            print("Loaded and playable")
        }
        self.logView.text = "\(Date()) Before loadValuesAsynchronously"
        avAsset.loadValuesAsynchronously(forKeys: [AVPlayerKeys.tracks, AVPlayerKeys.playable]) { [weak self] in
            self?.logView.text = (self?.logView.text ?? "") + "\(Date()) We are in the callback!!!!"
        }
    }
}

