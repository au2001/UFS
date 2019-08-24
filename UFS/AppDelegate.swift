//
//  AppDelegate.swift
//  UFS
//
//  Created by Aurélien Garnier on 20/08/2019.
//  Copyright © 2019 JustKodding. All rights reserved.
//

import Cocoa

private let kUFSMountPath = "/Volumes/UFS"
private let kUFSVolumeName = "UFS Drive"

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var menu: NSMenu!
    private var statusItem: NSStatusItem?
    
    private var driveStorage: DriveStorage?
    
    private var notificationObservers: [NSObjectProtocol] = []
    private var mountNotificationCallbacks: [(Error?) -> ()] = []
    private var unmountNotificationCallbacks: [(Error?) -> ()] = []
    
    private var fileSystem: FileSystem?
    private var userFileSystem: GMUserFileSystem?
    private var mounted = false

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        self.addNotifications()
        self.mount { error in
            if let error = error {
                let alert = NSAlert()
                alert.messageText = "Mount Failed"
                alert.informativeText = error.localizedDescription
                alert.runModal()
                return
            }
            
            DispatchQueue.main.sync {
                self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
                self.statusItem?.menu = self.menu
                self.statusItem?.button?.image = NSImage(named: "MenuIcon")
                self.statusItem?.button?.imageScaling = NSImageScaling.scaleProportionallyDown
                self.statusItem?.button?.toolTip = "UFS"
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        self.unmount { error in
            if let error = error {
                NSApplication.shared.reply(toApplicationShouldTerminate: false)
                
                let alert = NSAlert()
                alert.messageText = "Unmount Failed"
                alert.informativeText = error.localizedDescription
                alert.runModal()
                return
            }

            self.notificationObservers.forEach { observer in
                NotificationCenter.default.removeObserver(observer)
            }
            self.notificationObservers.removeAll()
            
            self.mountNotificationCallbacks.forEach { callback in
                callback(UFSError.closing)
            }
            self.mountNotificationCallbacks.removeAll()
            
            self.unmountNotificationCallbacks.forEach { callback in
                callback(UFSError.closing)
            }
            self.unmountNotificationCallbacks.removeAll()
            
            NSApplication.shared.reply(toApplicationShouldTerminate: true)
        }

        return .terminateLater
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach { url in
            if self.driveStorage?.handle(url: url) ?? false {
                return
            }
        }
    }
    
    private func addNotifications() {
        let mountObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name(kGMUserFileSystemDidMount), object: nil, queue: nil) { notification in
            guard notification.userInfo?[kGMUserFileSystemMountPathKey] as? String == kUFSMountPath else {
                return
            }
            
            self.mounted = true
            
            if !self.mountNotificationCallbacks.isEmpty {
                var callbacks: [(Error?) -> ()] = []
                callbacks.append(contentsOf: self.mountNotificationCallbacks)
                self.mountNotificationCallbacks.removeAll()
                callbacks.forEach { callback in
                    callback(nil)
                }
            }
        }
        
        let failedObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name(kGMUserFileSystemMountFailed), object: nil, queue: .main) { notification in
            guard notification.userInfo?[kGMUserFileSystemMountPathKey] as? String == kUFSMountPath else {
                return
            }
            
            self.mounted = false
            
            let error = notification.userInfo![kGMUserFileSystemErrorKey] as! NSError
            
            if !self.mountNotificationCallbacks.isEmpty {
                var callbacks: [(Error?) -> ()] = []
                callbacks.append(contentsOf: self.mountNotificationCallbacks)
                self.mountNotificationCallbacks.removeAll()
                callbacks.forEach { callback in
                    callback(error)
                }
            } else {
                let alert = NSAlert()
                alert.messageText = "Mount Failed"
                alert.informativeText = error.localizedDescription
                alert.runModal()
                
                NSApplication.shared.terminate(nil)
            }
        }
        
        let unmountObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name(kGMUserFileSystemDidUnmount), object: nil, queue: nil) { notification in
            guard notification.userInfo?[kGMUserFileSystemMountPathKey] as? String == kUFSMountPath else {
                return
            }
            
            self.mounted = false
            
            if !self.unmountNotificationCallbacks.isEmpty {
                var callbacks: [(Error?) -> ()] = []
                callbacks.append(contentsOf: self.unmountNotificationCallbacks)
                self.unmountNotificationCallbacks.removeAll()
                callbacks.forEach { callback in
                    callback(nil)
                }
            } else {
                NSApplication.shared.terminate(nil)
            }
        }
        
        self.notificationObservers = [mountObserver, failedObserver, unmountObserver]
    }
    
    public func signIn(callback: ((Error?) -> ())?) {
        if self.driveStorage == nil {
            let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            let cacheName = Bundle.main.object(forInfoDictionaryKey: "CFBundleIdentifier") as! String
            let cachePath = (cachesDirectory ?? URL(fileURLWithPath: ".", isDirectory: true)).appendingPathComponent(cacheName, isDirectory: true)
            self.driveStorage = DriveStorage(withCacheOfSize: 200 * 1024 * 1024, atPath: cachePath.absoluteString)
        }
        
        let driveStorage = self.driveStorage!
        
        driveStorage.signIn { error in
            if let error = error {
                callback?(error)
                return
            }
            
            callback?(nil)
        }
    }
    
    public func signOut(callback: ((Error?) -> ())?) {
        self.unmount { error in
            if let error = error {
                callback?(error)
                return
            }
            
            self.driveStorage?.signOut()
            callback?(nil)
        }
    }
    
    public func mount(callback: ((Error?) -> ())?) {
        if self.mounted {
            callback?(nil)
            return
        }
        
        guard let driveStorage = self.driveStorage, self.driveStorage?.isSignedIn() ?? false else {
            self.signIn { error in
                if let error = error {
                    callback?(error)
                    return
                }
                
                self.mount(callback: callback)
            }
            return
        }

        if self.fileSystem == nil {
            self.fileSystem = FileSystem(withStorage: driveStorage)
        }

        if self.userFileSystem == nil {
            self.userFileSystem = GMUserFileSystem(delegate: self.fileSystem, isThreadSafe: false)
        }
        
        let userFileSystem = self.userFileSystem!
        
        var options: [String] = ["allow_other", "volname=\(kUFSVolumeName)"]
        
        if let volumeIconPath = Bundle.main.path(forResource: "volicon", ofType: "icns") {
            options.insert("volicon=\(volumeIconPath)", at: 0)
        }
        
        if let callback = callback {
            self.mountNotificationCallbacks.append(callback)
        }
        
        userFileSystem.mount(atPath: kUFSMountPath, withOptions: options)
    }
    
    public func unmount(callback: ((Error?) -> ())?) {
        if !self.mounted {
            callback?(nil)
            return
        }
        
        guard let userFileSystem = self.userFileSystem else {
            callback?(UFSError.unmounted)
            return
        }
        
        if let callback = callback {
            self.unmountNotificationCallbacks.append(callback)
        }

        userFileSystem.unmount()
    }

}

