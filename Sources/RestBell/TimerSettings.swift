import AppKit
import OSLog
import ServiceManagement
import SwiftUI

enum TimerSettings {
    static let workKey = "workMinutes"
    static let restKey = "restMinutes"
    static let bellKey = "bellSound"
    static let defaultWork = 25
    static let defaultRest = 5
    static let minuteRange = 1...999

    static var bellSound: BellSound {
        UserDefaults.standard.string(forKey: bellKey).flatMap(BellSound.init(rawValue:)) ?? .system
    }

    static func clamp(_ minutes: Int) -> Int {
        min(max(minutes, minuteRange.lowerBound), minuteRange.upperBound)
    }

    static func minutes(from input: String) -> Int? {
        guard let minutes = Int(input.trimmingCharacters(in: .whitespacesAndNewlines)),
              minuteRange.contains(minutes) else { return nil }
        return minutes
    }

    static func minutes(for session: TimerModel.Session) -> Int {
        let key = session == .work ? workKey : restKey
        let fallback = session == .work ? defaultWork : defaultRest
        let minutes = UserDefaults.standard.object(forKey: key) as? Int ?? fallback
        return clamp(minutes)
    }

    static func duration(for session: TimerModel.Session) -> Duration {
        .seconds(minutes(for: session) * 60)
    }
}

enum LaunchAtLogin {
    private static let configuredKey = "didConfigureLaunchAtLogin"

    static func configureDefault() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: configuredKey) else { return }

        let installFolder = Bundle.main.bundleURL.deletingLastPathComponent().standardizedFileURL.path
        let applicationsFolders = FileManager.default.urls(for: .applicationDirectory, in: [.localDomainMask, .userDomainMask])
        guard applicationsFolders.contains(where: { $0.standardizedFileURL.path == installFolder }) else { return }

        switch SMAppService.mainApp.status {
        case .notRegistered, .notFound:
            do {
                try setEnabled(true)
            } catch {
                let failure = error as NSError
                Logger(subsystem: "local.restbell", category: "Login")
                    .error("Open at Login registration failed. \(failure.domain, privacy: .public) \(failure.code)")
            }
        case .enabled, .requiresApproval:
            defaults.set(true, forKey: configuredKey)
        @unknown default:
            break
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled {
            try service.register()
        } else {
            try service.unregister()
        }
        UserDefaults.standard.set(true, forKey: configuredKey)
    }
}

struct TimerSettingsView: View {
    @AppStorage(TimerSettings.workKey) private var workMinutes = TimerSettings.defaultWork
    @AppStorage(TimerSettings.restKey) private var restMinutes = TimerSettings.defaultRest
    @AppStorage(TimerSettings.bellKey) private var sound = BellSound.system
    @State private var preview = BellPlayer()
    @State private var loginStatus = SMAppService.mainApp.status
    @State private var loginError: String?

    private var launchAtLogin: Binding<Bool> {
        Binding {
            loginStatus == .enabled || loginStatus == .requiresApproval
        } set: { enabled in
            setLaunchAtLogin(enabled)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 18) {
                DurationField(title: "Work", minutes: $workMinutes)
                DurationField(title: "Rest", minutes: $restMinutes)
            }
            .frame(maxWidth: .infinity)
            Text("Both durations accept 1–999 minutes. Changes apply to the next session of that type.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()

            HStack {
                Picker("Bell sound", selection: $sound) {
                    ForEach(BellSound.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                Button("Play") {
                    preview.play(sound)
                }
                .accessibilityLabel("Play selected bell sound")
            }

            Divider()

            Toggle("Open RestBell at login", isOn: launchAtLogin)
                .toggleStyle(.checkbox)
            if loginStatus == .requiresApproval {
                Text("Allow RestBell in System Settings to open it at login.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Open Login Items", action: SMAppService.openSystemSettingsLoginItems)
            }
            if let loginError {
                Text(loginError)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 370)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            loginStatus = SMAppService.mainApp.status
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.setEnabled(enabled)
            loginError = nil
        } catch {
            loginError = "Couldn’t update Open at Login. \(error.localizedDescription)"
        }
        loginStatus = SMAppService.mainApp.status
    }
}

private struct DurationField: View {
    let title: String
    @Binding var minutes: Int
    @State private var draft: String?
    @FocusState private var isEditing: Bool

    private var savedMinutes: Int {
        TimerSettings.clamp(minutes)
    }

    private var enteredMinutes: Int? {
        draft.flatMap(TimerSettings.minutes(from:))
    }

    var body: some View {
        let input = Binding {
            draft ?? String(savedMinutes)
        } set: { value in
            draft = value
        }
        let stepperValue = Binding {
            enteredMinutes ?? savedMinutes
        } set: { value in
            apply(value)
        }

        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(title)
                TextField("\(title) minutes", text: input)
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(minWidth: 48, maxWidth: .infinity)
                    .focused($isEditing)
                    .onSubmit(commit)
                Stepper("Adjust \(title.lowercased()) minutes", value: stepperValue, in: TimerSettings.minuteRange)
                    .labelsHidden()
            }
            if draft != nil && enteredMinutes == nil {
                Label("Enter a whole number from 1 to 999.", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("\(title) duration must be a whole number from 1 to 999 minutes.")
            }
        }
        .onChange(of: isEditing) { _, editing in
            if !editing { commit() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            if isEditing { commit() }
        }
    }

    private func commit() {
        guard let enteredMinutes else { return }
        apply(enteredMinutes)
    }

    private func apply(_ value: Int) {
        if value != minutes { minutes = value }
        draft = nil
    }
}
