//
//  AppDelegate.swift
//  UFS
//
//  Created by Aurélien Garnier on 20/08/2019.
//  Copyright © 2019 JustKodding. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var menu: NSMenu!
    private var statusItem: NSStatusItem?
    
    private var notificationObservers: [NSObjectProtocol] = []
    
    private lazy var desktopPath = (NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true) as [String]).first!
    private lazy var ufs: UFS = {
        return UFS(rootPath: self.desktopPath)
    }()
    private lazy var userFileSystem: GMUserFileSystem = {
        return GMUserFileSystem(delegate: self.ufs, isThreadSafe: false)
    }()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.statusItem?.menu = self.menu
        self.statusItem?.button?.image = NSImage(named: "MenuIcon")
        self.statusItem?.button?.imageScaling = NSImageScaling.scaleProportionallyDown
        self.statusItem?.button?.toolTip = "UFS"
        
        addNotifications()
        
        var options: [String] = ["allow_other", "volname=UFS"]
        
        if let volumeIconPath = Bundle.main.path(forResource: "volicon", ofType: "icns") {
            options.insert("volicon=\(volumeIconPath)", at: 0)
        }

        userFileSystem.mount(atPath: "/Volumes/ufs", withOptions: options)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        notificationObservers.forEach {
            NotificationCenter.default.removeObserver($0)
        }
        notificationObservers.removeAll()
        
        userFileSystem.unmount()
        return .terminateNow
    }
    
    func addNotifications() {
        let mountObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name(kGMUserFileSystemDidMount), object: nil, queue: nil) { notification in
            print("Got didMount notification.")
            
            guard let userInfo = notification.userInfo, let mountPath = userInfo[kGMUserFileSystemMountPathKey] as? String else { return }
            
            let parentPath = (mountPath as NSString).deletingLastPathComponent
            NSWorkspace.shared.selectFile(mountPath, inFileViewerRootedAtPath: parentPath)
        }
        
        let failedObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name(kGMUserFileSystemMountFailed), object: nil, queue: .main) { notification in
            print("Got mountFailed notification.")
            
            guard let userInfo = notification.userInfo, let error = userInfo[kGMUserFileSystemErrorKey] as? NSError else { return }
            
            print("kGMUserFileSystem Error: \(error), userInfo=\(error.userInfo)")
            let alert = NSAlert()
            alert.messageText = "Mount Failed"
            alert.informativeText = "Failed to mount UFS on \(error.userInfo["mountPath"] ?? "<Unknown Mount Path>")"
            alert.runModal()
            
            NSApplication.shared.terminate(nil)
        }
        
        let unmountObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name(kGMUserFileSystemDidUnmount), object: nil, queue: nil) { notification in
            print("Got didUnmount notification.")
            
            NSApplication.shared.terminate(nil)
        }
        
        self.notificationObservers = [mountObserver, failedObserver, unmountObserver]
    }

}

