import SwiftUI
import QuickLook

struct PLYViewer: View {
    let plyURL: URL

    var body: some View {
        if QLPreviewController.canPreview(plyURL as QLPreviewItem) {
            QuickLookPreview(url: plyURL)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "questionmark.folder")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("Preview not available for this file")
                    .font(.headline)
                Text(plyURL.lastPathComponent)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

private struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        // No-op
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL

        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}
