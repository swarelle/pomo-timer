//
//  PomoTimer
//
//  Created by swarelle in Feb 2026.
//
import SwiftUI
import UserNotifications
import ServiceManagement

// MARK: - App

@main
struct PomodoroTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene { Settings { EmptyView() } }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    
    var statusItem: NSStatusItem?
    var timer: Timer?
    var endTime: Date?  // Track when timer should end
    var totalSeconds = 25 * 60
    var hasNotifiedFiveMinutes = false
    var hasNotifiedOneMinute = false
    var notificationSound = "Glass"
    
    // Computed property to get current remaining seconds
    private var remainingSeconds: Int {
        guard let endTime = endTime else { return 0 }
        return max(0, Int(endTime.timeIntervalSince(Date())))
    }
    
    let availableSounds = ["Default", "Glass", "Basso", "Blow", "Bottle", "Frog",
                           "Funk", "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi",
                           "Submarine", "Tink"]
    
    // MARK: Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        loadPreferences()
        NSApp.setActivationPolicy(.accessory)
        setupNotifications()
        createMenuBar()
    }
    
    private func loadPreferences() {
        if let saved = UserDefaults.standard.string(forKey: "notificationSound"),
           availableSounds.contains(saved) {
            notificationSound = saved
        }
    }
    
    private func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if !granted { print("⚠️ Notifications not allowed") }
        }
    }
    
    private func createMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "🍅"
        setupMenu()
    }
    
    // MARK: Menu Setup
    
    func setupMenu() {
        let menu = NSMenu()
        
        // Status
        let status = NSMenuItem(title: "Ready to start", action: nil, keyEquivalent: "")
        status.tag = 100
        menu.addItem(status)
        menu.addItem(.separator())
        
        // Sound menu
        let soundMenu = NSMenuItem(title: "Notification Sound", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for sound in availableSounds {
            let item = NSMenuItem(title: sound, action: #selector(selectSound(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = sound
            item.state = (sound == notificationSound) ? .on : .off
            submenu.addItem(item)
        }
        soundMenu.submenu = submenu
        menu.addItem(soundMenu)
        menu.addItem(.separator())
        
        // Mode selector
        let modeView = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 30))
        let modeLabel = NSTextField(labelWithString: "Mode:")
        modeLabel.frame = NSRect(x: 10, y: 5, width: 45, height: 20)
        modeView.addSubview(modeLabel)
        
        let modeControl = NSSegmentedControl(frame: NSRect(x: 60, y: 5, width: 150, height: 20))
        modeControl.segmentCount = 2
        modeControl.setLabel("Duration", forSegment: 0)
        modeControl.setLabel("End Time", forSegment: 1)
        modeControl.selectedSegment = 0
        modeControl.target = self
        modeControl.action = #selector(modeChanged(_:))
        modeControl.tag = 300
        modeView.addSubview(modeControl)
        
        let modeItem = NSMenuItem()
        modeItem.view = modeView
        menu.addItem(modeItem)
        
        // Duration input
        let durationView = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 30))
        let durationLabel = NSTextField(labelWithString: "Duration (min):")
        durationLabel.frame = NSRect(x: 10, y: 5, width: 100, height: 20)
        durationView.addSubview(durationLabel)
        
        let durationField = NSTextField(frame: NSRect(x: 120, y: 5, width: 80, height: 20))
        durationField.stringValue = "25"
        durationField.tag = 200
        durationField.target = self
        durationField.action = #selector(startTimerFromField)
        durationView.addSubview(durationField)
        
        let durationItem = NSMenuItem()
        durationItem.view = durationView
        durationItem.tag = 201
        menu.addItem(durationItem)
        
        // End time input
        let endTimeView = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 30))
        let endTimeLabel = NSTextField(labelWithString: "End time (HH:MM):")
        endTimeLabel.frame = NSRect(x: 10, y: 5, width: 120, height: 20)
        endTimeView.addSubview(endTimeLabel)
        
        let endTimeField = NSTextField(frame: NSRect(x: 135, y: 5, width: 65, height: 20))
        endTimeField.tag = 202
        endTimeField.target = self
        endTimeField.action = #selector(startTimerFromField)
        endTimeView.addSubview(endTimeField)
        
        let endTimeItem = NSMenuItem()
        endTimeItem.view = endTimeView
        endTimeItem.tag = 203
        endTimeItem.isHidden = true
        menu.addItem(endTimeItem)
        menu.addItem(.separator())
        
        // Timer controls
        let start = NSMenuItem(title: "Start Timer", action: #selector(startTimer), keyEquivalent: "")
        start.target = self
        start.tag = 101
        menu.addItem(start)
        
        let stop = NSMenuItem(title: "Stop Timer", action: #selector(stopTimer), keyEquivalent: "")
        stop.target = self
        stop.tag = 102
        stop.isHidden = true
        menu.addItem(stop)
        menu.addItem(.separator())
        
        // Launch at login
        let launch = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launch.target = self
        launch.tag = 103
        launch.state = getLaunchAtLoginStatus() ? .on : .off
        menu.addItem(launch)
        menu.addItem(.separator())
        
        // Test lock
        let test = NSMenuItem(title: "Test Screen Lock", action: #selector(testLock), keyEquivalent: "")
        test.target = self
        menu.addItem(test)
        menu.addItem(.separator())
        
        // Quit
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    // MARK: Actions
    
    @objc func selectSound(_ sender: NSMenuItem) {
        guard let sound = sender.representedObject as? String else { return }
        notificationSound = sound
        UserDefaults.standard.set(sound, forKey: "notificationSound")
        
        // Update checkmarks
        if let submenu = statusItem?.menu?.items.first(where: { $0.title == "Notification Sound" })?.submenu {
            submenu.items.forEach { $0.state = ($0.representedObject as? String == sound) ? .on : .off }
        }
        
        // Preview
        let content = UNMutableNotificationContent()
        content.title = "Sound Preview"
        content.body = "This is how your notifications will sound"
        content.sound = (sound == "Default") ? .default : UNNotificationSound(named: UNNotificationSoundName("\(sound).aiff"))
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
    
    @objc func modeChanged(_ sender: NSSegmentedControl) {
        guard let menu = statusItem?.menu else { return }
        let isDuration = (sender.selectedSegment == 0)
        menu.item(withTag: 201)?.isHidden = !isDuration
        menu.item(withTag: 203)?.isHidden = isDuration
        
        // Update end time to 25 minutes from now when switching to End Time mode
        if !isDuration {
            if let endTimeField = menu.item(withTag: 203)?.view?.viewWithTag(202) as? NSTextField {
                let futureTime = Date().addingTimeInterval(25 * 60)
                let calendar = Calendar.current
                let hour = calendar.component(.hour, from: futureTime)
                let minute = calendar.component(.minute, from: futureTime)
                endTimeField.stringValue = String(format: "%02d:%02d", hour, minute)
            }
        }
    }
    
    @objc func startTimerFromField() {
        statusItem?.menu?.cancelTracking()
        startTimer()
    }
    
    @objc func startTimer() {
        guard let menu = statusItem?.menu else { return }
        
        // Prevent multiple timers from running
        timer?.invalidate()
        timer = nil
        
        let modeControl = menu.items.first(where: { $0.view?.viewWithTag(300) != nil })?.view?.viewWithTag(300) as? NSSegmentedControl
        let isDuration = (modeControl?.selectedSegment == 0)
        
        if isDuration {
            guard let field = menu.item(withTag: 201)?.view?.viewWithTag(200) as? NSTextField,
                  let minutes = Int(field.stringValue), minutes > 0 else {
                showAlert("Please enter a valid duration in minutes.")
                return
            }
            totalSeconds = minutes * 60
        } else {
            guard let field = menu.item(withTag: 203)?.view?.viewWithTag(202) as? NSTextField,
                  let seconds = parseTime(field.stringValue.trimmingCharacters(in: .whitespaces)) else {
                showAlert("Please enter a valid time in 24-hour format (HH:MM)")
                return
            }
            guard seconds > 0 else {
                showAlert("End time must be in the future.")
                return
            }
            totalSeconds = seconds
        }
        
        // Set end time based on current time + duration
        endTime = Date().addingTimeInterval(TimeInterval(totalSeconds))
        hasNotifiedFiveMinutes = false
        hasNotifiedOneMinute = false
        menu.item(withTag: 101)?.isHidden = true
        menu.item(withTag: 102)?.isHidden = false
        
        // Create timer - it will check actual time remaining each tick
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer?.tolerance = 0.1
        
        updateDisplay()
    }
    
    private func parseTime(_ time: String) -> Int? {
        let parts = time.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]), h >= 0, h < 24,
              let m = Int(parts[1]), m >= 0, m < 60 else { return nil }
        
        var target = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        target.hour = h
        target.minute = m
        target.second = 0
        
        guard let date = Calendar.current.date(from: target) else { return nil }
        return Int(date.timeIntervalSince(Date()))
    }
    
    @objc func stopTimer() {
        timer?.invalidate()
        timer = nil
        endTime = nil
        
        guard let menu = statusItem?.menu else { return }
        menu.item(withTag: 101)?.isHidden = false
        menu.item(withTag: 102)?.isHidden = true
        menu.item(withTag: 100)?.title = "Ready to start"
        statusItem?.button?.title = "🍅"
    }
    
    func tick() {
        guard timer != nil, endTime != nil else { return }
        
        // Get actual remaining seconds from computed property
        let remaining = remainingSeconds
        
        // Check for notifications at specific thresholds
        if remaining <= 300 && remaining > 299 && !hasNotifiedFiveMinutes {
            notify(title: "5 Minutes Left", body: "Your Pomodoro session is almost done!")
            hasNotifiedFiveMinutes = true
        }
        
        if remaining <= 60 && remaining > 59 && !hasNotifiedOneMinute {
            notify(title: "1 Minute Left", body: "Wrapping up your Pomodoro session!")
            hasNotifiedOneMinute = true
        }
        
        // Check if timer is complete
        if remaining <= 0 {
            timer?.invalidate()
            timer = nil
            endTime = nil
            stopTimer()
            notify(title: "Pomodoro Complete!", body: "Great work! Time for a break.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.lockScreen()
            }
            return
        }
        
        updateDisplay()
    }
    
    private func updateDisplay() {
        let remaining = remainingSeconds
        let m = remaining / 60
        let s = remaining % 60
        let time = String(format: "%d:%02d", m, s)
        statusItem?.button?.title = "🍅 \(time)"
        statusItem?.menu?.item(withTag: 100)?.title = "Time remaining: \(time)"
    }
    
    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = (notificationSound == "Default") ? .default : UNNotificationSound(named: UNNotificationSoundName("\(notificationSound).aiff"))
        content.interruptionLevel = .timeSensitive
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
    
    private func lockScreen() {
        // Use private API SACLockScreenImmediate for instant lock
        let libHandle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY)
        guard let handle = libHandle else {
            print("Failed to load login framework")
            fallbackLock()
            return
        }
        
        guard let sym = dlsym(handle, "SACLockScreenImmediate") else {
            print("Failed to find SACLockScreenImmediate symbol")
            dlclose(handle)
            fallbackLock()
            return
        }
        
        typealias LockScreenFunction = @convention(c) () -> Void
        let lockScreen = unsafeBitCast(sym, to: LockScreenFunction.self)
        lockScreen()
        dlclose(handle)
    }
    
    private func fallbackLock() {
        // Fallback to pmset if private API fails
        let task = Process()
        task.launchPath = "/usr/bin/pmset"
        task.arguments = ["displaysleepnow"]
        try? task.run()
    }
    
    @objc func testLock() {
        let alert = NSAlert()
        alert.messageText = "Test Screen Lock"
        alert.informativeText = "This will lock your screen in 2 seconds."
        alert.addButton(withTitle: "Test")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { self.lockScreen() }
        }
    }
    
    @objc func toggleLaunchAtLogin() {
        guard #available(macOS 13.0, *) else {
            showAlert("Launch at login requires macOS 13 or later.")
            return
        }
        
        let isEnabled = SMAppService.mainApp.status == .enabled
        do {
            if isEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            statusItem?.menu?.item(withTag: 103)?.state = isEnabled ? .off : .on
        } catch {
            showAlert("Could not change launch at login setting.")
        }
    }
    
    private func getLaunchAtLoginStatus() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
    
    private func showAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Pomodoro Timer"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: Notification Delegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification,
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(macOS 12.0, *) {
            completionHandler([.list, .banner, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }
}
