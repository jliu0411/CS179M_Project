import Foundation

@MainActor
final class ScanViewModel: ObservableObject {
    let cameraManager = TrueDepthCameraManager()
    private let api = ApiClient()

    @Published var isBusy = false
    @Published var measurement: BoxMeasurement?
    @Published var status: String = "Point the front camera at an object up close."

    func captureAndMeasure() async {
        guard !isBusy else { return }

        isBusy = true
        measurement = nil
        status = "Capturing depth frame..."

        do {
            let plyURL = try await cameraManager.capturePLY()
            status = "Uploading to server..."
            let result = try await api.uploadPLY(fileURL: plyURL)
            measurement = result
            status = "Done"
        } catch {
            status = "Error: \(error.localizedDescription)"
        }

        isBusy = false
    }
}