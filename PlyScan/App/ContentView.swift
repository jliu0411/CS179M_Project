//
//  ContentView.swift
//  PlyScan
//
//  Created by Dongyeon Kim on 2/25/26.
//

import SwiftUI
import ARKit
import RealityKit

struct ContentARViewContainer: UIViewRepresentable {

    let sessionManager: ARSessionManager

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.session = sessionManager.session
        sessionManager.startSession()
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}

struct ContentView: View {

    @StateObject var sessionManager = ARSessionManager()
    @State private var isScanning = false

    var body: some View {
        ZStack {
            if sessionManager.scanMode == .trueDepth {

                TrueDepthView(scanner: sessionManager.trueDepthScanner)
                    .edgesIgnoringSafeArea(.all)

            } else {

                ContentARViewContainer(sessionManager: sessionManager)
                    .edgesIgnoringSafeArea(.all)
            }

            VStack {
                Text({
                    switch sessionManager.scanMode {
                    case .lidar: return "Mode: LiDAR"
                    case .trueDepth: return "Mode: TrueDepth"
                    case .rgb: return "Mode: RGB"
                    }
                }())
                .padding(6)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                
                Spacer()
                
                if isScanning {
                    CoverageRingView(coverage: sessionManager.coveragePercent)
                }
                
                if sessionManager.coveragePercent < 40 && isScanning {
                    Text("Move around object")
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
                else if sessionManager.coveragePercent < 80 && isScanning {
                    Text("Almost full circle")
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
                else if isScanning {
                    Text("Great coverage!")
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
                
                Spacer()
                
                if isScanning {
                    Text("Frames: \(sessionManager.frameCount)")
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                    Text("Height Levels: \(sessionManager.heightCoverage)/2")
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }

                Button(action: {
                    isScanning.toggle()
                    sessionManager.setScanning(isScanning)
                }) {
                    Text(isScanning ? "Stop Scan" : "Start Scan")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                }
                .padding()
            }
        }
    }
}

