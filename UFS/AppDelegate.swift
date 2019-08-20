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

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application

        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength);
        self.statusItem?.menu = self.menu;
        self.statusItem?.button?.image = NSImage(named: "MenuIcon");
        self.statusItem?.button?.imageScaling = NSImageScaling.scaleProportionallyDown;
        self.statusItem?.button?.toolTip = "UFS";
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}

