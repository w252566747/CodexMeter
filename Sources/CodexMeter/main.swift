import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var usagePopover: NSPopover?
    private var usageDetailsView: UsageDetailsView?
    private var popoverWindowObserver: NSObjectProtocol?
    private var appActivationObserver: NSObjectProtocol?
    private var globalClickMonitor: Any?
    private var statusItem: NSStatusItem?
    private var statusView: UsageStatusView?
    private var usage: Usage?
    private var refreshTimer: Timer?
    private var creditsRefreshTimer: Timer?
    private var resetCredits: ResetCreditsResponse?
    private var creditsRequestFailed = false
    private var language = AppLanguage.saved

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("CodexMeter applicationDidFinishLaunching")
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        refresh()
        refreshResetCredits()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        creditsRefreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshResetCredits() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
        creditsRefreshTimer?.invalidate()
        removePopoverObservers()
    }

    @objc private func refresh() {
        Task { [weak self] in
            do {
                let loaded = try await UsageService.load()
                self?.usage = loaded
                self?.updateViews()
                self?.updateDetailsView(usage: loaded, credits: self?.resetCredits, creditsUnavailable: self?.creditsRequestFailed ?? false)
            } catch {
                self?.showError(error)
            }
        }
    }

    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: 116)
        item.button?.title = ""
        item.button?.target = self
        item.button?.action = #selector(showStatusUsageDetails)
        let view = UsageStatusView(frame: NSRect(x: 0, y: 0, width: 116, height: 22))
        view.autoresizingMask = [.width, .height]
        item.button?.addSubview(view)
        statusItem = item
        statusView = view
    }

    @objc private func showStatusUsageDetails() {
        guard let button = statusItem?.button else { return }
        if let usagePopover, usagePopover.isShown {
            usagePopover.performClose(button)
            return
        }
        let details = UsageDetailsView(
            usage: usage,
            credits: resetCredits,
            creditsUnavailable: creditsRequestFailed,
            language: language,
            localized: { [weak self] key in self?.localized(key) ?? key },
            onLanguageChange: { [weak self] language in self?.selectLanguage(language) }
        )
        let controller = NSViewController()
        controller.view = details
        let popover = NSPopover()
        popover.contentViewController = controller
        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = details.frame.size
        usagePopover = popover
        usageDetailsView = details
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        observePopoverDismissal(popover)
        refresh()
    }

    func popoverShouldClose(_ popover: NSPopover) -> Bool { true }

    func popoverDidClose(_ notification: Notification) {
        removePopoverObservers()
        usageDetailsView = nil
        usagePopover = nil
    }

    private func observePopoverDismissal(_ popover: NSPopover) {
        removePopoverObservers()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self, weak popover] _ in
            DispatchQueue.main.async {
                guard let self,
                      let popover,
                      popover.isShown,
                      let popoverWindow = popover.contentViewController?.view.window
                else { return }
                let pointer = NSEvent.mouseLocation
                let popupFrame = popoverWindow.frame
                let buttonFrame = self.statusItem?.button?.window?.convertToScreen(self.statusItem?.button?.frame ?? .zero) ?? .zero
                guard !popupFrame.contains(pointer), !buttonFrame.contains(pointer) else { return }
                popover.performClose(self.statusItem?.button)
            }
        }
        if let window = popover.contentViewController?.view.window {
            popoverWindowObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: window,
                queue: .main
            ) { [weak self, weak popover] _ in
                DispatchQueue.main.async {
                    guard let self, let popover, popover.isShown else { return }
                    popover.performClose(self.statusItem?.button)
                }
            }
        }
        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self, weak popover] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            DispatchQueue.main.async {
                guard let self, let popover, popover.isShown else { return }
                popover.performClose(self.statusItem?.button)
            }
        }
    }

    private func removePopoverObservers() {
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
            self.globalClickMonitor = nil
        }
        if let popoverWindowObserver {
            NotificationCenter.default.removeObserver(popoverWindowObserver)
            self.popoverWindowObserver = nil
        }
        if let appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(appActivationObserver)
            self.appActivationObserver = nil
        }
    }

    private func refreshResetCredits() {
        Task { [weak self] in
            do {
                let credits = try await UsageService.loadResetCredits()
                self?.resetCredits = credits
                self?.creditsRequestFailed = false
                self?.updateDetailsView(usage: self?.usage, credits: credits, creditsUnavailable: false)
            } catch {
                self?.creditsRequestFailed = true
                self?.updateDetailsView(usage: self?.usage, credits: self?.resetCredits, creditsUnavailable: true)
            }
        }
    }

    private func updateDetailsView(usage: Usage?, credits: ResetCreditsResponse?, creditsUnavailable: Bool) {
        usageDetailsView?.update(usage: usage, credits: credits, creditsUnavailable: creditsUnavailable, language: language)
        if let usageDetailsView { usagePopover?.contentSize = usageDetailsView.frame.size }
    }

    private func selectLanguage(_ language: AppLanguage) {
        guard self.language != language else { return }
        self.language = language
        UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.preferenceKey)
        updateViews()
        updateDetailsView(usage: usage, credits: resetCredits, creditsUnavailable: creditsRequestFailed)
    }

    private func updateViews() {
        guard let usage else { return }
        let short = "5h \(usage.primaryRemaining)%"
        let weekly = "7d \(usage.secondaryRemaining)%"
        statusItem?.button?.toolTip = String(format: localized("usage_tooltip"), short, weekly)
        let primaryWindow = usage.rate_limit.primary_window
        let weeklyWindow = usage.rate_limit.secondary_window
        statusView?.update(
            primaryRemaining: usage.primaryRemaining,
            secondaryRemaining: usage.secondaryRemaining,
            primaryTimeRemaining: usage.timeRemainingFraction(for: primaryWindow, periodSeconds: 5 * 60 * 60),
            secondaryTimeRemaining: usage.timeRemainingFraction(for: weeklyWindow, periodSeconds: 7 * 24 * 60 * 60),
            primaryCountdown: usage.compactResetCountdown(for: primaryWindow, isWeekly: false),
            secondaryCountdown: usage.compactResetCountdown(for: weeklyWindow, isWeekly: true)
        )
    }

    private func showError(_ error: Error) {
        statusItem?.button?.toolTip = String(format: localized("usage_error"), error.localizedDescription)
        statusView?.showError()
    }

    private func localized(_ key: String) -> String {
        language.localized(key)
    }
}

private enum AppLanguage: String, CaseIterable {
    case simplifiedChinese = "zh-Hans"
    case japanese = "ja"
    case english = "en"

    static let preferenceKey = "preferredLanguage"

    static var saved: AppLanguage {
        if let value = UserDefaults.standard.string(forKey: preferenceKey), let saved = AppLanguage(rawValue: value) {
            return saved
        }
        let systemLanguage = Locale.preferredLanguages.first ?? "zh-Hans"
        if systemLanguage.hasPrefix("ja") { return .japanese }
        if systemLanguage.hasPrefix("en") { return .english }
        return .simplifiedChinese
    }

    var displayName: String {
        switch self {
        case .simplifiedChinese: "中文"
        case .japanese: "日本語"
        case .english: "English"
        }
    }

    var localeIdentifier: String { rawValue }

    func localized(_ key: String) -> String {
        guard let path = Bundle.main.path(forResource: rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}

@MainActor
private final class UsageStatusView: NSView {
    private var primary = 0
    private var secondary = 0
    private var primaryTimeRemaining: CGFloat?
    private var secondaryTimeRemaining: CGFloat?
    private var primaryCountdown = "--"
    private var secondaryCountdown = "--"
    private var failed = false

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(
        primaryRemaining: Int,
        secondaryRemaining: Int,
        primaryTimeRemaining: CGFloat?,
        secondaryTimeRemaining: CGFloat?,
        primaryCountdown: String,
        secondaryCountdown: String
    ) {
        primary = primaryRemaining
        secondary = secondaryRemaining
        self.primaryTimeRemaining = primaryTimeRemaining
        self.secondaryTimeRemaining = secondaryTimeRemaining
        self.primaryCountdown = primaryCountdown
        self.secondaryCountdown = secondaryCountdown
        failed = false
        needsDisplay = true
    }

    func showError() {
        failed = true
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let bounds = self.bounds.insetBy(dx: 1, dy: 1)
        NSColor.controlBackgroundColor.withAlphaComponent(0.42).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()

        if failed {
            drawText("Codex !", in: bounds, font: .systemFont(ofSize: 11, weight: .semibold), color: .systemRed)
            return
        }

        drawRing(at: NSPoint(x: 5, y: 3), remainingTime: primaryTimeRemaining, label: primaryCountdown, color: .systemGreen)
        drawText("\(primary)%", in: NSRect(x: 29, y: 4, width: 26, height: 15), font: .monospacedDigitSystemFont(ofSize: 10, weight: .semibold), color: .labelColor)
        NSColor.separatorColor.setFill()
        NSBezierPath(rect: NSRect(x: 58, y: 5, width: 1, height: 12)).fill()
        drawRing(at: NSPoint(x: 63, y: 3), remainingTime: secondaryTimeRemaining, label: secondaryCountdown, color: .systemBlue)
        drawText("\(secondary)%", in: NSRect(x: 87, y: 4, width: 27, height: 15), font: .monospacedDigitSystemFont(ofSize: 10, weight: .semibold), color: .labelColor)
    }

    private func drawRing(at origin: NSPoint, remainingTime: CGFloat?, label: String, color: NSColor) {
        let rect = NSRect(origin: origin, size: NSSize(width: 20, height: 20))
        let background = NSBezierPath(ovalIn: rect.insetBy(dx: 1.5, dy: 1.5))
        background.lineWidth = 2.2
        NSColor.tertiaryLabelColor.withAlphaComponent(0.45).setStroke()
        background.stroke()

        if let remainingTime, remainingTime > 0 {
            let ring = NSBezierPath()
            ring.appendArc(withCenter: NSPoint(x: rect.midX, y: rect.midY), radius: 8.5, startAngle: 90, endAngle: 90 - (360 * min(1, max(0, remainingTime))), clockwise: true)
            ring.lineWidth = 2.2
            ring.lineCapStyle = .round
            color.setStroke()
            ring.stroke()
        }
        let fontSize: CGFloat = label.count > 2 ? 6 : 7
        drawText(label, in: rect.insetBy(dx: 1, dy: 5), font: .systemFont(ofSize: fontSize, weight: .bold), color: .labelColor)
    }

    private func drawText(_ text: String, in rect: NSRect, font: NSFont, color: NSColor) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: style]
        NSAttributedString(string: text, attributes: attributes).draw(in: rect)
    }
}

@main
struct CodexMeterMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

private struct Usage: Decodable {
    struct Window: Decodable {
        let used_percent: Int
        let reset_at: Double?
        let reset_after_seconds: Double?
    }
    struct RateLimit: Decodable {
        let primary_window: Window
        let secondary_window: Window
    }
    struct ResetCreditSummary: Decodable {
        let available_count: Int?
    }
    struct FlexibleDate: Decodable {
        let date: Date?
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let seconds = try? container.decode(Double.self) {
                date = Date(timeIntervalSince1970: seconds > 10_000_000_000 ? seconds / 1000 : seconds)
            } else if let value = try? container.decode(String.self) {
                if let seconds = Double(value) {
                    date = Date(timeIntervalSince1970: seconds > 10_000_000_000 ? seconds / 1000 : seconds)
                } else {
                    let iso = ISO8601DateFormatter()
                    let fractionalISO = ISO8601DateFormatter()
                    fractionalISO.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    date = iso.date(from: value) ?? fractionalISO.date(from: value)
                }
            } else {
                date = nil
            }
        }
    }
    let rate_limit: RateLimit
    let rate_limit_reset_credits: ResetCreditSummary?
    var primaryRemaining: Int { max(0, 100 - rate_limit.primary_window.used_percent) }
    var secondaryRemaining: Int { max(0, 100 - rate_limit.secondary_window.used_percent) }

    func resetDate(for window: Window) -> Date? {
        if let reset_at = window.reset_at { return Date(timeIntervalSince1970: reset_at) }
        if let seconds = window.reset_after_seconds { return Date().addingTimeInterval(seconds) }
        return nil
    }

    func secondsUntilReset(for window: Window) -> Int? {
        guard let date = resetDate(for: window) else { return nil }
        return max(0, Int(ceil(date.timeIntervalSinceNow)))
    }

    func timeRemainingFraction(for window: Window, periodSeconds: Int) -> CGFloat? {
        guard let seconds = secondsUntilReset(for: window), periodSeconds > 0 else { return nil }
        return CGFloat(min(1, max(0, Double(seconds) / Double(periodSeconds))))
    }

    func compactResetCountdown(for window: Window, isWeekly: Bool) -> String {
        guard let seconds = secondsUntilReset(for: window) else { return "--" }
        if isWeekly {
            if seconds >= 86_400 { return "\(seconds / 86_400)d" }
            if seconds >= 3_600 { return "\(seconds / 3_600)h" }
            return "\((seconds + 59) / 60)m"
        }
        if seconds >= 3_600 { return "\(seconds / 3_600)h" }
        return "\((seconds + 59) / 60)m"
    }

    func resetCountdown(for window: Window, isWeekly: Bool, localized: (String) -> String) -> String {
        guard let seconds = secondsUntilReset(for: window) else { return localized("not_reported") }
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        if isWeekly {
            return String(format: localized("resets_in_days_hours"), days, hours)
        }
        return String(format: localized("resets_in_hours_minutes"), seconds / 3_600, minutes)
    }

}

private struct ResetCreditsResponse: Decodable {
    struct Credit: Decodable {
        let id: String
        let status: String?
        let expires_at: Usage.FlexibleDate?
        var expiresAt: Date? { expires_at?.date }
    }
    let available_count: Int?
    let credits: [Credit]?
}

@MainActor
private final class UsageDetailsView: NSView {
    private let stack = NSStackView()
    private let localized: (String) -> String
    private let onLanguageChange: (AppLanguage) -> Void
    private var language: AppLanguage

    init(usage: Usage?, credits: ResetCreditsResponse?, creditsUnavailable: Bool, language: AppLanguage, localized: @escaping (String) -> String, onLanguageChange: @escaping (AppLanguage) -> Void) {
        self.localized = localized
        self.language = language
        self.onLanguageChange = onLanguageChange
        super.init(frame: NSRect(x: 0, y: 0, width: 340, height: 176))
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -14)
        ])
        update(usage: usage, credits: credits, creditsUnavailable: creditsUnavailable, language: language)
    }

    required init?(coder: NSCoder) { nil }

    func update(usage: Usage?, credits: ResetCreditsResponse?, creditsUnavailable: Bool, language: AppLanguage) {
        self.language = language
        for view in stack.arrangedSubviews {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        defer { resizeToFit() }

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 8
        header.widthAnchor.constraint(equalToConstant: 308).isActive = true
        let title = NSTextField(labelWithString: localized("usage_details"))
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        let spacer = NSView()
        let languageLabel = NSTextField(labelWithString: localized("language"))
        languageLabel.font = .systemFont(ofSize: 11)
        let languagePicker = NSPopUpButton()
        languagePicker.addItems(withTitles: AppLanguage.allCases.map(\.displayName))
        languagePicker.selectItem(at: AppLanguage.allCases.firstIndex(of: language) ?? 0)
        languagePicker.target = self
        languagePicker.action = #selector(changeLanguage(_:))
        languagePicker.widthAnchor.constraint(equalToConstant: 92).isActive = true
        header.addArrangedSubview(title)
        header.addArrangedSubview(spacer)
        header.addArrangedSubview(languageLabel)
        header.addArrangedSubview(languagePicker)
        stack.addArrangedSubview(header)
        if let usage {
            stack.addArrangedSubview(usageWindowLine("5h", text: usage.resetCountdown(for: usage.rate_limit.primary_window, isWeekly: false, localized: localized), color: .systemGreen))
            stack.addArrangedSubview(usageWindowLine("7d", text: usage.resetCountdown(for: usage.rate_limit.secondary_window, isWeekly: true, localized: localized), color: .systemBlue))
        } else {
            stack.addArrangedSubview(line(localized("usage"), text: localized("loading_usage")))
        }
        let count = credits?.available_count ?? usage?.rate_limit_reset_credits?.available_count
        if let count {
            stack.addArrangedSubview(line(localized("reset_cards"), text: String(format: localized("reset_cards_count"), count)))
        } else if creditsUnavailable {
            stack.addArrangedSubview(line(localized("reset_cards"), text: localized("credits_unavailable")))
            return
        } else if credits == nil {
            stack.addArrangedSubview(line(localized("reset_cards"), text: localized("loading_usage")))
            return
        }
        guard let credits else {
            if creditsUnavailable { stack.addArrangedSubview(line(localized("expires_at"), text: localized("credits_unavailable"))) }
            return
        }
        guard let creditRows = credits.credits else {
            if (count ?? 0) > 0 {
                stack.addArrangedSubview(line(localized("expires_at"), text: localized("credits_unavailable")))
            }
            return
        }
        let available = creditRows.filter { $0.status == nil || $0.status == "available" }
        for (index, credit) in available.enumerated() {
            let label = String(format: localized("reset_card_number"), index + 1)
            let expiration: String
            if let date = credit.expiresAt {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: language.localeIdentifier)
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                expiration = formatter.string(from: date)
            } else {
                expiration = localized("no_expiration")
            }
            stack.addArrangedSubview(line(label, text: "\(localized("expires_at")): \(expiration)"))
        }
    }

    @objc private func changeLanguage(_ sender: NSPopUpButton) {
        guard AppLanguage.allCases.indices.contains(sender.indexOfSelectedItem) else { return }
        onLanguageChange(AppLanguage.allCases[sender.indexOfSelectedItem])
    }

    private func resizeToFit() {
        stack.layoutSubtreeIfNeeded()
        setFrameSize(NSSize(width: 340, height: max(120, stack.fittingSize.height + 28)))
    }

    private func line(_ label: String, text: String) -> NSView {
        let field = NSTextField(labelWithString: "\(label): \(text)")
        field.font = .systemFont(ofSize: 11)
        return field
    }

    private func usageWindowLine(_ label: String, text: String, color: NSColor) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.edgeInsets = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)

        let badge = NSTextField(labelWithString: label)
        badge.font = .systemFont(ofSize: 11, weight: .bold)
        badge.textColor = color
        badge.alignment = .center
        badge.wantsLayer = true
        badge.layer?.backgroundColor = color.withAlphaComponent(0.14).cgColor
        badge.layer?.cornerRadius = 5
        badge.widthAnchor.constraint(equalToConstant: 32).isActive = true

        let detail = NSTextField(labelWithString: text)
        detail.font = .systemFont(ofSize: 12, weight: .semibold)
        detail.textColor = .labelColor

        row.addArrangedSubview(badge)
        row.addArrangedSubview(detail)
        row.wantsLayer = true
        row.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.85).cgColor
        row.layer?.cornerRadius = 8
        return row
    }
}

private enum UsageService {
    private struct AuthFile: Decodable {
        struct Tokens: Decodable {
            let access_token: String
            let account_id: String?
        }
        let tokens: Tokens
    }

    private static func loadAuth() throws -> AuthFile {
        let authURL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".codex/auth.json")
        return try JSONDecoder().decode(AuthFile.self, from: Data(contentsOf: authURL))
    }

    static func load() async throws -> Usage {
        let auth = try loadAuth()
        var request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
        addAuthHeaders(auth, to: &request)
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(Usage.self, from: data)
    }

    static func loadResetCredits() async throws -> ResetCreditsResponse {
        let auth = try loadAuth()
        var request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits")!)
        addAuthHeaders(auth, to: &request)
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ResetCreditsResponse.self, from: data)
    }

    private static func addAuthHeaders(_ auth: AuthFile, to request: inout URLRequest) {
        request.setValue("Bearer \(auth.tokens.access_token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let accountID = auth.tokens.account_id {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }
    }
}
