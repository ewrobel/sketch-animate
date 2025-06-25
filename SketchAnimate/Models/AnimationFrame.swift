//
//  AnimationFrame.swift
//  SketchAnimate
//
//  Created by Emily Wrobel on 6/23/25.
//

import Foundation

struct AnimationFrame {
    let paths: [DrawingPath]
    let frameNumber: Int
    let timestamp: Double
    
    init(paths: [DrawingPath], frameNumber: Int) {
        self.paths = paths
        self.frameNumber = frameNumber
        self.timestamp = Double(frameNumber) / 10.0 // 10 FPS
    }
}

// Extension for debugging
extension AnimationFrame {
    var description: String {
        return "Frame \(frameNumber): \(paths.count) paths at \(String(format: "%.1f", timestamp))s"
    }
}
