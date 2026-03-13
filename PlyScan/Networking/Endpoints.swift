//
//  Endpoints.swift
//  PlyScan
//
//  Created by Dongyeon Kim on 2/25/26.
//

import Foundation

enum Endpoint {
    case uploadPLY
    case downloadCleaned(filename: String)
    case health
    
    var path: String {
        switch self {
        case .uploadPLY:
            return "/api/upload-ply"
        case .downloadCleaned(let filename):
            return "/api/download-cleaned/\(filename)"
        case .health:
            return "/api/health"
        }
    }
}
