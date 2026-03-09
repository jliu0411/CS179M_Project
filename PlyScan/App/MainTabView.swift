//
//  MainTabView.swift
//  PlyScan
//
//  Created on 3/8/26.
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var libraryManager = LibraryManager.shared
    
    var body: some View {
        TabView {
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "folder.fill")
                }
            
            ScanView()
                .tabItem {
                    Label("Scan", systemImage: "camera.fill")
                }
            
            ManualUploadView()
                .tabItem {
                    Label("Upload", systemImage: "arrow.up.doc.fill")
                }
        }
    }
}
