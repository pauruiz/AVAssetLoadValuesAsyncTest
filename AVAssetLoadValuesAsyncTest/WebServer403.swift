//
//  WebServer403.swift
//  AVAssetLoadValuesAsyncTest
//
//  Created by Ruiz, Pablo (Developer) on 30/10/2017.
//  Copyright © 2017 BSKYB. All rights reserved.
//

import Foundation
import CocoaAsyncSocket

@objc class WebServer403: NSObject {
    var listenSocket: GCDAsyncSocket?
    var sockets: [GCDAsyncSocket] = []
    
    public func listen(port: UInt16) -> Bool {
        if listenSocket == nil {
            let newListenSocket = GCDAsyncSocket()
            newListenSocket.delegate = self
            newListenSocket.delegateQueue = DispatchQueue.global()
            listenSocket = newListenSocket
            do {
                // TODO: We can try to listen only on localhost interface, but it should not make any difference
                try newListenSocket.accept(onPort: port)
                return true
            } catch let error {
                print("\(error)")
            }
        }
        return false
    }

    public func close() {
        for socket in sockets {
            socket.disconnect()
        }
        listenSocket?.disconnect()
    }
    
    deinit {
        close()
    }
}

extension WebServer403: GCDAsyncSocketDelegate {
    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        self.sockets.append(newSocket)
        
        print("Web Server: New socket connection")
        
        newSocket.readData(withTimeout: -1, tag: 0)
    }
    
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        if let outputData = "HTTP/1.1 403 Forbidden - 403.2 Resource conflict\nConnection: keep-alive\nContent-Length:  0\n\n".data(using: .utf8) {
            let string: String = String(data: data, encoding: .utf8) ?? ""
            print("Web Server: Returned 403 to a incoming data:\n\(string)")
            sock.write(outputData, withTimeout: 120, tag: 0)
            sock.readData(withTimeout: -1, tag: 0)
        }
    }
    
    func socket(_ sock: GCDAsyncSocket, didReadPartialDataOfLength partialLength: UInt, tag: Int) {
        print("Web Server: Partial data")
    }
    
    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        print("Web Server: 403 Text sent correctly")
    }
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        self.sockets = self.sockets.filter { $0 != sock }
        print("Web Server: Socket disconnected")
    }
}
