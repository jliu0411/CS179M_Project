//
//  TrueDepthView.swift
//  PlyScan
//
//  Created by Dongyeon Kim on 3/4/26.
//

import SwiftUI
import AVFoundation

struct TrueDepthView: UIViewRepresentable {

    let scanner: TrueDepthScanner

    func makeUIView(context: Context) -> UIView {

        let view = UIView()

        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in

            if let preview = scanner.previewLayer {

                preview.frame = view.bounds
                preview.videoGravity = .resizeAspectFill

                view.layer.addSublayer(preview)

                print("Preview attached")

                timer.invalidate()
            }
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {

        scanner.previewLayer?.frame = uiView.bounds
    }
}
