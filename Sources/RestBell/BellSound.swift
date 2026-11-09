import AppKit

enum BellSound: String, CaseIterable {
    case system = "System Alert"
    case tink = "Tink"
    case bottle = "Bottle"
    case morse = "Morse"
    case frog = "Frog"
    case purr = "Purr"
    case basso = "Basso"

    var clip: NSSound? {
        self == .system ? nil : NSSound(named: rawValue)
    }
}

@MainActor
final class BellPlayer {
    private var playing: NSSound?

    func play(_ selection: BellSound) {
        stop()
        if let sound = selection.clip {
            sound.currentTime = 0
            if sound.play() {
                playing = sound
                return
            }
        }
        NSSound.beep()
    }

    func stop() {
        playing?.stop()
        playing = nil
    }
}
