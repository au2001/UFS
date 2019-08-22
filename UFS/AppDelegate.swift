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
    
    private var driveStorage: DriveStorage?
    
    private var notificationObservers: [NSObjectProtocol] = []
    
    private lazy var desktopPath = (NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true) as [String]).first!
    private lazy var ufs: UFS = {
        return UFS(rootPath: self.desktopPath)
    }()
    private lazy var userFileSystem: GMUserFileSystem = {
        return GMUserFileSystem(delegate: self.ufs, isThreadSafe: false)
    }()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let driveStorage = DriveStorage()
        if !driveStorage.isSignedIn() {
            driveStorage.signIn { (error) in
                if let error = error {
                    print("Google Drive Auth Error: \(error)")
                    let alert = NSAlert()
                    alert.messageText = "Authentication Failed"
                    alert.informativeText = "Failed to login to Google Drive, please try again."
                    alert.runModal()
                } else {
                    print("Successfully authenticated on Google Drive as \(driveStorage.getUserEmail() ?? "nil").")
                }
            }
        } else {
            print("Successfully authenticated on Google Drive as \(driveStorage.getUserEmail() ?? "nil").")
        }
        self.driveStorage = driveStorage
        
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.statusItem?.menu = self.menu
        self.statusItem?.button?.image = NSImage(named: "MenuIcon")
        self.statusItem?.button?.imageScaling = NSImageScaling.scaleProportionallyDown
        self.statusItem?.button?.toolTip = "UFS"
        
        self.addNotifications()
        
        var options: [String] = ["allow_other", "volname=UFS"]
        
        if let volumeIconPath = Bundle.main.path(forResource: "volicon", ofType: "icns") {
            options.insert("volicon=\(volumeIconPath)", at: 0)
        }

        self.userFileSystem.mount(atPath: "/Volumes/ufs", withOptions: options)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        self.userFileSystem.unmount()
        return .terminateLater
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard self.driveStorage?.handle(url: url) ?? false else {
                continue
            }
            
            // TODO: Handle URL
        }
    }
    
    func addNotifications() {
        let mountObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name(kGMUserFileSystemDidMount), object: nil, queue: nil) { notification in
            
            guard let userInfo = notification.userInfo, let mountPath = userInfo[kGMUserFileSystemMountPathKey] as? String else {
                print("Successfully mounted, failed to fetch mount path.")
                return
            }
            
            print("Successfully mounted on \(mountPath).")
        }
        
        let failedObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name(kGMUserFileSystemMountFailed), object: nil, queue: .main) { notification in
            guard let userInfo = notification.userInfo, let mountPath = userInfo[kGMUserFileSystemMountPathKey] as? String, let error = userInfo[kGMUserFileSystemErrorKey] as? NSError else {
                print("Failed to mount, failed to fetch mount path.")
                return
            }
            
            print("Failed to mount on \(mountPath).")
            
            print("kGMUserFileSystem Error: \(error), userInfo=\(userInfo)")
            let alert = NSAlert()
            alert.messageText = "Mount Failed"
            alert.informativeText = "Failed to mount on \(mountPath)."
            alert.runModal()
            
            NSApplication.shared.terminate(nil)
        }
        
        let unmountObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name(kGMUserFileSystemDidUnmount), object: nil, queue: nil) { notification in
            print("Succesfully un-mounted.")
            
            self.notificationObservers.forEach {
                NotificationCenter.default.removeObserver($0)
            }
            self.notificationObservers.removeAll()
            
            NSApplication.shared.reply(toApplicationShouldTerminate: true)
            NSApplication.shared.terminate(nil)
        }
        
        self.notificationObservers = [mountObserver, failedObserver, unmountObserver]
    }

}

