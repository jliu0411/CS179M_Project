//
//  ManualUploadView.swift
//  PlyScan
//
//  Created on 3/8/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct ManualUploadView: View {
    @State private var showingFilePicker = false
    @State private var selectedFileURL: URL?
    @State private var isUploading = false
    @State private var uploadResult: UploadResponse?
    @State private var errorMessage: String?
    @State private var showingResult = false
    @State private var hasRequestedNetworkPermission = false
    
    @StateObject private var serverDiscovery = ServerDiscovery.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.up.doc.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Manual PLY Upload")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Select a PLY file from your device to process and measure")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 40)
                    
                    // File Selection
                    if let fileURL = selectedFileURL {
                        GroupBox {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Selected File")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(fileURL.lastPathComponent)
                                        .font(.headline)
                                    
                                    if let fileSize = getFileSize(fileURL) {
                                        Text("\(fileSize) KB")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    selectedFileURL = nil
                                    uploadResult = nil
                                    errorMessage = nil
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.title2)
                                }
                            }
                            .padding()
                        }
                        .padding(.horizontal)
                    }
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            showingFilePicker = true
                        }) {
                            Label("Choose PLY File", systemImage: "folder")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .disabled(isUploading)
                        
                        if selectedFileURL != nil {
                            Button(action: uploadFile) {
                                HStack {
                                    if isUploading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        Text("Processing...")
                                    } else {
                                        Label("Process File", systemImage: "gearshape.arrow.triangle.2.circlepath")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(isUploading)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Error Message
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    
                    // Results
                    if let result = uploadResult {
                        GroupBox(label: Label("Measurement Results", systemImage: "checkmark.circle.fill").foregroundColor(.green)) {
                            VStack(spacing: 16) {
                                MeasurementCard(label: "Width", value: result.dimensions.width, color: .blue)
                                MeasurementCard(label: "Length", value: result.dimensions.length, color: .green)
                                MeasurementCard(label: "Height", value: result.dimensions.height, color: .orange)
                                
                                Button(action: {
                                    saveToLibrary(result: result)
                                }) {
                                    Label("Save to Library", systemImage: "folder.badge.plus")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.purple)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                            }
                            .padding()
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Upload")
            .sheet(isPresented: $showingFilePicker) {
                DocumentPicker(selectedURL: $selectedFileURL)
            }
            .onAppear {
                // Trigger network permission prompt on first view
                if !hasRequestedNetworkPermission {
                    hasRequestedNetworkPermission = true
                    // This will trigger the local network permission prompt
                    serverDiscovery.getServerURL { url in
                        if let url = url {
                            NSLog("✅ Server discovered: \(url)")
                        } else {
                            NSLog("⚠️ No server found on local network")
                        }
                    }
                }
            }
        }
    }
    
    private func getFileSize(_ url: URL) -> String? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? Int64 else {
            return nil
        }
        return String(format: "%.1f", Double(fileSize) / 1024.0)
    }
    
    private func uploadFile() {
        guard let fileURL = selectedFileURL else { return }
        
        isUploading = true
        errorMessage = nil
        uploadResult = nil
        
        UploadService.shared.uploadPLY(fileURL: fileURL, scanMode: .rgb) { result in
            DispatchQueue.main.async {
                isUploading = false
                
                switch result {
                case .success(let response):
                    uploadResult = response
                case .failure(let error):
                    errorMessage = "Upload failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func saveToLibrary(result: UploadResponse) {
        guard let fileURL = selectedFileURL else { return }
        
        let record = ScanRecord(
            filename: result.originalFilename,
            dimensions: ScanRecord.Dimensions(
                width: result.dimensions.width,
                height: result.dimensions.height,
                length: result.dimensions.length
            ),
            scanMode: "Manual Upload",
            localPath: fileURL.path
        )
        
        LibraryManager.shared.addRecord(record)
        
        // Show confirmation
        errorMessage = nil
        uploadResult = nil
        selectedFileURL = nil
        
        // Could add a toast notification here
    }
}

// Document Picker for selecting PLY files
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType(filenameExtension: "ply")!])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Start accessing security-scoped resource
            _ = url.startAccessingSecurityScopedResource()
            
            // Copy to temp directory for processing
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.removeItem(at: tempURL)
            try? FileManager.default.copyItem(at: url, to: tempURL)
            
            parent.selectedURL = tempURL
            
            url.stopAccessingSecurityScopedResource()
        }
    }
}
