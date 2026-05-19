import UIKit
import SwiftUI
import UniformTypeIdentifiers
import SwiftData

/// Build 22: Share-extension entry point. iOS instantiates this when the
/// user picks "Save to Cadence" from any share sheet. We pull the shared
/// item out of the NSExtensionItem attachments and hand it to the SwiftUI
/// `ShareCaptureView` which renders the form.
final class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // Resolve the shared text / URL on the main queue, then mount the
        // SwiftUI form once we have a string to pre-fill.
        Task { [weak self] in
            guard let self else { return }
            let prefill = await Self.resolveSharedString(from: self.extensionContext)
            await MainActor.run {
                self.presentForm(initialText: prefill)
            }
        }
    }

    private func presentForm(initialText: String) {
        let context: NSExtensionContext? = self.extensionContext
        let host = UIHostingController(rootView: ShareCaptureView(
            initialText: initialText,
            onSave: { [weak self] in
                self?.complete(success: true)
            },
            onCancel: { [weak self] in
                self?.complete(success: false)
            }
        ))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        _ = context // silence
    }

    private func complete(success: Bool) {
        if success {
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        } else {
            extensionContext?.cancelRequest(withError: NSError(
                domain: "net.mcinnis.cadence.share",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Cancelled"]
            ))
        }
    }

    /// Walks the extension's input items for text or a URL we can use as
    /// the task title. Falls back to empty string if nothing's there.
    private static func resolveSharedString(from context: NSExtensionContext?) async -> String {
        guard let items = context?.inputItems as? [NSExtensionItem] else { return "" }
        for item in items {
            for attachment in item.attachments ?? [] {
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let url = try? await attachment.loadItem(
                        forTypeIdentifier: UTType.url.identifier
                    ) as? URL {
                        return url.absoluteString
                    }
                }
                if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let text = try? await attachment.loadItem(
                        forTypeIdentifier: UTType.plainText.identifier
                    ) as? String {
                        return text
                    }
                }
            }
            // Fall back to attributed content title if present.
            if let title = item.attributedContentText?.string, !title.isEmpty {
                return title
            }
            if let title = item.attributedTitle?.string, !title.isEmpty {
                return title
            }
        }
        return ""
    }
}
