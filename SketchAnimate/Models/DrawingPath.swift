//
//  DrawingPath.swift
//  SketchAnimate
//
//  Created by Emily Wrobel on 6/23/25.
//

import SwiftUI

struct DrawingPath {
    var points: [CGPoint] = []
    var path: Path = Path()
    
    // Helper to rebuild path from points
    mutating func rebuildPath() {
        guard !points.isEmpty else { return }
        
        path = Path()
        path.move(to: points[0])
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
    }
    
    // Calculate bounding box for this path
    var boundingBox: CGRect {
        guard !points.isEmpty else { return .zero }
        
        let minX = points.map { $0.x }.min() ?? 0
        let maxX = points.map { $0.x }.max() ?? 0
        let minY = points.map { $0.y }.min() ?? 0
        let maxY = points.map { $0.y }.max() ?? 0
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    // Check if this path is roughly vertical
    var isVertical: Bool {
        guard let first = points.first, let last = points.last else { return false }
        let dx = abs(last.x - first.x)
        let dy = abs(last.y - first.y)
        return dy > dx * 1.5 && dy > 30
    }
    
    // Check if this path is roughly horizontal
    var isHorizontal: Bool {
        guard let first = points.first, let last = points.last else { return false }
        let dx = abs(last.x - first.x)
        let dy = abs(last.y - first.y)
        return dx > dy * 1.5 && dx > 20
    }
}
