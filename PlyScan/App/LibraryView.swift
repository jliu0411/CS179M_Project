//
//  LibraryView.swift
//  PlyScan
//
//  Created on 3/8/26.
//

import SwiftUI

struct LibraryView: View {
    @StateObject private var libraryManager = LibraryManager.shared
    @State private var selectedRecord: ScanRecord?
    
    var body: some View {
        NavigationView {
            List {
                if libraryManager.scanRecords.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No scans yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Scan objects or upload PLY files to see them here")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(libraryManager.scanRecords) { record in
                        Button(action: {
                            selectedRecord = record
                        }) {
                            ScanRecordRow(record: record)
                        }
                    }
                    .onDelete(perform: deleteRecords)
                }
            }
            .navigationTitle("Scan Library")
            .toolbar {
                if !libraryManager.scanRecords.isEmpty {
                    EditButton()
                }
            }
            .sheet(item: $selectedRecord) { record in
                ScanDetailView(record: record)
            }
        }
    }
    
    private func deleteRecords(at offsets: IndexSet) {
        for index in offsets {
            let record = libraryManager.scanRecords[index]
            libraryManager.deleteRecord(record)
        }
    }
}

struct ScanRecordRow: View {
    let record: ScanRecord
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.filename)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(formatDate(record.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: modeIcon(for: record.scanMode))
                        .font(.caption)
                    Text(record.scanMode)
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }
            
            Spacer()
            
            if let dims = record.dimensions {
                VStack(alignment: .trailing, spacing: 2) {
                    dimensionText("W: \(String(format: "%.3f", dims.width))m")
                    dimensionText("L: \(String(format: "%.3f", dims.length))m")
                    dimensionText("H: \(String(format: "%.3f", dims.height))m")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            } else {
                Text("Processing...")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func dimensionText(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func modeIcon(for mode: String) -> String {
        switch mode {
        case "LiDAR": return "light.beacon.max"
        case "TrueDepth": return "camera.metering.matrix"
        case "RGB": return "camera"
        default: return "camera"
        }
    }
}

struct ScanDetailView: View {
    let record: ScanRecord
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // File Info
                    GroupBox(label: Label("File Information", systemImage: "doc.circle")) {
                        VStack(alignment: .leading, spacing: 8) {
                            DetailRow(label: "Filename", value: record.filename)
                            DetailRow(label: "Date", value: formatDate(record.timestamp))
                            DetailRow(label: "Scan Mode", value: record.scanMode)
                            DetailRow(label: "Local Path", value: record.localPath, isPath: true)
                        }
                    }
                    
                    // Dimensions
                    if let dims = record.dimensions {
                        GroupBox(label: Label("Dimensions", systemImage: "ruler")) {
                            VStack(spacing: 12) {
                                MeasurementCard(label: "Width", value: dims.width, color: .blue)
                                MeasurementCard(label: "Length", value: dims.length, color: .green)
                                MeasurementCard(label: "Height", value: dims.height, color: .orange)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Scan Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var isPath: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(isPath ? .caption2 : .body)
                .foregroundColor(.primary)
        }
    }
}

struct MeasurementCard: View {
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: "ruler.fill")
                .foregroundColor(color)
            
            Text(label)
                .font(.headline)
            
            Spacer()
            
            Text("\(String(format: "%.3f", value)) m")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

