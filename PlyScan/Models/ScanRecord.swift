//
//  ScanRecord.swift
//  PlyScan
//
//  Created on 3/8/26.
//

import Foundation

struct ScanRecord: Identifiable, Codable {
    let id: UUID
    let filename: String
    let timestamp: Date
    let dimensions: Dimensions?
    let scanMode: String
    let localPath: String
    
    struct Dimensions: Codable {
        let width: Double
        let height: Double
        let length: Double
    }
    
    init(id: UUID = UUID(), filename: String, timestamp: Date = Date(), dimensions: Dimensions? = nil, scanMode: String, localPath: String) {
        self.id = id
        self.filename = filename
        self.timestamp = timestamp
        self.dimensions = dimensions
        self.scanMode = scanMode
        self.localPath = localPath
    }
}
