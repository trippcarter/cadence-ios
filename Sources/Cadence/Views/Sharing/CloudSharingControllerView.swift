import SwiftUI
import CloudKit
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
/// SwiftUI wrapper around Apple's UICloudSharingController. Presents the
/// system "Invite People" sheet so users can manage participants, choose a
/// share method (Messages, Mail, copy link), and adjust permissions —
/// without us re-implementing any of that UI.
struct CloudSharingControllerView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let vc = UICloudSharingController(share: share, container: container)
        vc.availablePermissions = [.allowReadWrite, .allowReadOnly, .allowPrivate]
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        func itemTitle(for csc: UICloudSharingController) -> String? {
            csc.share?[CKShare.SystemFieldKey.title] as? String ?? "Cadence list"
        }
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            // Surface in console for now; a future polish would route this
            // back to the calling view's @State via a binding.
            NSLog("[Cadence-Share] failed to save share: %@", error.localizedDescription)
        }
        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            NSLog("[Cadence-Share] share saved")
        }
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            NSLog("[Cadence-Share] sharing stopped")
        }
    }
}
#endif
