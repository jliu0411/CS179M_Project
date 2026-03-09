//
//  CoverageRingView.swift
//  PlyScan
//
//  Created by Dongyeon Kim on 3/4/26.
//

import SwiftUI

struct CoverageRingView: View {
    
    var coverage: Int
    
    var body: some View {
        
        ZStack {
            
            Circle()
                .stroke(lineWidth: 12)
                .opacity(0.2)
                .foregroundColor(.white)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(coverage) / 100.0)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [.green, .yellow, .orange]),
                        center: .center
                    ),
                    style: StrokeStyle(
                        lineWidth: 12,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.2), value: coverage)
            
            VStack {
                Text("\(coverage)%")
                    .font(.title)
                    .bold()
                
                Text("Coverage")
                    .font(.caption)
                    .opacity(0.7)
                
            }
            
        }
        .frame(width: 120, height: 120)
    }
}
