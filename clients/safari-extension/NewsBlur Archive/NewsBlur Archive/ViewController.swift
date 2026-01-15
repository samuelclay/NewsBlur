// NewsBlur Archive - Main View Controller
// Displays information about the Safari extension and how to enable it

import Cocoa
import SafariServices

class ViewController: NSViewController {

    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var instructionsLabel: NSTextField!
    @IBOutlet weak var openSafariButton: NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        checkExtensionState()
    }

    private func setupUI() {
        statusLabel.stringValue = "Checking extension status..."
        instructionsLabel.stringValue = """
        To enable NewsBlur Archive:
        1. Open Safari
        2. Go to Safari → Settings → Extensions
        3. Enable "NewsBlur Archive"
        4. Allow access to all websites
        """
    }

    private func checkExtensionState() {
        SFSafariExtensionManager.getStateOfSafariExtension(
            withIdentifier: "com.newsblur.archive.extension"
        ) { [weak self] state, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.statusLabel.stringValue = "Error: \(error.localizedDescription)"
                    return
                }

                guard let state = state else {
                    self?.statusLabel.stringValue = "Unable to determine extension state"
                    return
                }

                if state.isEnabled {
                    self?.statusLabel.stringValue = "✓ NewsBlur Archive is enabled"
                    self?.statusLabel.textColor = .systemGreen
                } else {
                    self?.statusLabel.stringValue = "✗ NewsBlur Archive is not enabled"
                    self?.statusLabel.textColor = .systemRed
                }
            }
        }
    }

    @IBAction func openSafariPreferences(_ sender: Any) {
        SFSafariApplication.showPreferencesForExtension(
            withIdentifier: "com.newsblur.archive.extension"
        ) { error in
            if let error = error {
                print("Error opening Safari preferences: \(error)")
            }
        }
    }

    @IBAction func openNewsBlur(_ sender: Any) {
        if let url = URL(string: "https://newsblur.com/archive") {
            NSWorkspace.shared.open(url)
        }
    }

    @IBAction func refreshStatus(_ sender: Any) {
        checkExtensionState()
    }
}
