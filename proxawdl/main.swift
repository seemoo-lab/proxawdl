//
//  main.swift
//  proxAWDL
//
//  Created by Milan Stute on 01.03.18.
//  Copyright © 2018 SEEMOO. All rights reserved.
//

import Foundation

class ProxAWDL: NSObject, NetServiceDelegate, NetServiceBrowserDelegate, StreamDelegate, GCDAsyncSocketDelegate {
    
    var isServer = false
    
    let localPort: UInt16
    let remotePort: UInt16
    let serviceType = "_proxawdl._tcp"
    let serviceName = "proxAWDL"
    let serviceDomain = "local."
    
    var service: NetService?
    var browser: NetServiceBrowser?
    
    var remoteInputStream: InputStream?
    var remoteOutputStream: OutputStream?
    
    var localSocket: GCDAsyncSocket?
    var localAcceptSocket: GCDAsyncSocket?
    
    override convenience init() {
        self.init(withLocalPort: 22222, andRemotePort: 33333)
    }
    
    init(withLocalPort local: UInt16, andRemotePort remote: UInt16) {
        localPort = local
        remotePort = remote
        localSocket = GCDAsyncSocket()
    }
    
    func socket(_ socket : GCDAsyncSocket, didConnectToHost host:String, port p:UInt16) {
        print("Connected to", host, ":", p)
        print("Start reading")
        socket.readData(withTimeout: -1, tag: 0)
    }
    
    func socket(_ socket: GCDAsyncSocket, didRead data:Data, withTag tag: Int) {
        _ = data.withUnsafeBytes {(uint8Ptr: UnsafePointer<UInt8>) in
            if let remoteOutputStream = remoteOutputStream {
                remoteOutputStream.write(uint8Ptr as UnsafePointer<UInt8>, maxLength: data.count)
            } else {
                print("Warning: read data from local but no remote connection established")
            }
        }
        socket.readData(withTimeout: -1, tag: 0)
    }
    
    func socket(_ socket: GCDAsyncSocket, didAcceptNewSocket:GCDAsyncSocket) {
        print("accepted new connection")
        // keep socket alive
        localSocket = didAcceptNewSocket
        didAcceptNewSocket.readData(withTimeout: -1, tag: 0)
    }
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError error: Error?) {
        print("socket disconnect")
        if self.isServer {
            print("try again")
            try! sock.connect(toHost: "localhost", onPort: localPort)
        } else {
            print("wait for client to reconnect")
        }
    }
    
    func start_client_stub() {
        self.isServer = false

        print("proxAWDL in CLIENT mode")
        
        browser = NetServiceBrowser.init()
        if let browser = browser {
            browser.delegate = self
            browser.includesPeerToPeer = true
            print("Bonjour: start searching")
            browser.searchForServices(ofType: serviceType, inDomain: serviceDomain)
        }
    }
    
    func netServiceBrowser(_ sender: NetServiceBrowser, didFind: NetService, moreComing: Bool) {
        print("Bonjour: found ", didFind.name, "on port", didFind.port)
        didFind.delegate = self
        didFind.resolve(withTimeout: 0)
        service = didFind
    }
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        print("Bonjour: resolved proxy")
        print("streams created: ", sender.getInputStream(&remoteInputStream, outputStream: &remoteOutputStream))
        
        // start local socket once connection with remote proxy stub is established
        localAcceptSocket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
        if let localAcceptSocket = localAcceptSocket {
            try! localAcceptSocket.accept(onPort: localPort)
        }
        
        initRemoteStreams()
    }

    func start_server_stub() {
        self.isServer = true
        
        print("proxAWDL in SERVER mode")
        
        service = NetService.init(domain: serviceDomain, type: serviceType, name: serviceName, port: Int32(remotePort))
        
        localSocket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
        
        print("Proxy: connecting...")
        if let localServerSocket = localSocket {
            try! localServerSocket.connect(toHost: "localhost", onPort: localPort)
        }

        print("Bonjour: start listening")
        if let service = service {
            service.includesPeerToPeer = true
            service.delegate = self
            service.publish(options: .listenForConnections)
        }
    }

    func netService(_ sender: NetService,
                    didAcceptConnectionWith inputStream: InputStream,
                    outputStream: OutputStream) {
        print("didAcceptConnection", sender)
        remoteInputStream = inputStream
        remoteOutputStream = outputStream
        
        initRemoteStreams()
    }

    func initRemoteStreams() {
        remoteInputStream?.delegate = self
        remoteOutputStream?.delegate = self
        
        remoteInputStream?.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
        remoteOutputStream?.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
        
        remoteInputStream?.open()
        remoteOutputStream?.open()
    }
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case Stream.Event.hasBytesAvailable:
            var buf: [UInt8] = Array(repeating: 0, count: 65536)
            let read = remoteInputStream?.read(&buf, maxLength: buf.count)
            if let read = read {
                if let localSocket = localSocket {
                    let data = NSData.init(bytes: &buf, length: read)
                    localSocket.write(data as Data, withTimeout: -1, tag: 0)
                } else {
                    print("Warning: read data from remote but no local connection established")
                }
            } else {
                print("Could not read from remoteInputStream")
            }
            break
        case Stream.Event.errorOccurred:
            print("Remote event: error occured")
            break
        case Stream.Event.openCompleted:
            print("Remote event: open completed")
            break
        case Stream.Event.endEncountered:
            print("Remote event: end of stream reached")
            break
        case Stream.Event.hasSpaceAvailable:
            print("Remote event: has space available")
        default:
            print("other event")
        }
    }
}

var proxy = ProxAWDL()

var isClient = false

for arg in CommandLine.arguments {
    switch arg {
    case "client":
        isClient = true
        break
    default:
        break
    }
}

if isClient {
    proxy.start_client_stub()
} else {
    proxy.start_server_stub()
}

RunLoop.current.run()
