//
//  LibraryManager.swift
//  PlyScan
//
//  Created on 3/8/26.
//

import Foundation
import Combine

class LibraryManager: ObservableObject {
    static let shared = LibraryManager()
    
    @Published var scanRecords: [ScanRecord] = []
    
    private let userDefaultsKey = "scanRecords"
    
    private init() {
        loadRecords()
    }
    
    func addRecord(_ record: ScanRecord) {
        scanRecords.insert(record, at: 0) // Most recent first
        saveRecords()
    }
    
    func updateRecord(_ record: ScanRecord) {
        if let index = scanRecords.firstIndex(where: { $0.id == record.id }) {
            scanRecords[index] = record
            saveRecords()
        }
    }
    
    func deleteRecord(_ record: ScanRecord) {
        scanRecords.removeAll { $0.id == record.id }
        saveRecords()
        
        // Also delete the local file
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: record.localPath)
        try? fileManager.removeItem(at: url)
    }
    
    private func saveRecords() {
        if let encoded = try? JSONEncoder().encode(scanRecords) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    private func loadRecords() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([ScanRecord].self, from: data) {
            scanRecords = decoded
        }
    }
}
