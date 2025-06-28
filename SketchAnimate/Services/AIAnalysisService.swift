import Foundation
import UIKit
import SwiftUI

// Simple local analysis service - no API calls needed
class AIAnalysisService: ObservableObject {
    
    enum AIError: Error, LocalizedError {
        case analysisFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .analysisFailed(let message):
                return "Analysis failed: \(message)"
            }
        }
    }
    
    func analyzeDrawing(_ drawingPaths: [DrawingPath]) async throws -> ObjectType {
        // Simulate processing time for better UX
        try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
        
        print("🎯 Analyzing drawing with \(drawingPaths.count) paths")
        
        // Use enhanced local detection
        let detectedType = performLocalAnalysis(drawingPaths)
        
        print("✅ Local analysis result: \(detectedType.displayName)")
        return detectedType
    }
    
    // MARK: - Enhanced Local Analysis
    
    private func performLocalAnalysis(_ paths: [DrawingPath]) -> ObjectType {
        guard !paths.isEmpty else { return .unknown }
        
        let bounds = calculateDrawingBounds(paths)
        let aspectRatio = bounds.width / bounds.height
        let totalPoints = paths.reduce(0) { $0 + $1.points.count }
        
        print("📊 Drawing analysis:")
        print("  - Paths: \(paths.count)")
        print("  - Total points: \(totalPoints)")
        print("  - Aspect ratio: \(String(format: "%.2f", aspectRatio))")
        print("  - Bounds: \(Int(bounds.width))x\(Int(bounds.height))")
        
        // Enhanced stick figure detection
        if detectStickFigure(paths, bounds: bounds) {
            print("🎯 Detected: Human (stick figure)")
            return .human
        }
        
        // Enhanced ball detection
        if detectBall(paths, aspectRatio: aspectRatio) {
            print("🎯 Detected: Ball")
            return .ball
        }
        
        // Enhanced box detection
        if detectBox(paths, aspectRatio: aspectRatio) {
            print("🎯 Detected: Box")
            return .box
        }
        
        // Enhanced animal detection
        if detectAnimal(paths, bounds: bounds, aspectRatio: aspectRatio) {
            print("🎯 Detected: Animal")
            return .animal
        }
        
        print("🎯 Detected: Unknown drawing")
        return .unknown
    }
    
    // MARK: - Detection Methods
    
    private func detectStickFigure(_ paths: [DrawingPath], bounds: CGRect) -> Bool {
        // Look for main body (vertical line)
        let hasMainBody = paths.contains { path in
            let pathBounds = path.boundingBox
            return pathBounds.height > pathBounds.width &&
                   pathBounds.height > 40 &&
                   pathBounds.height > bounds.height * 0.3
        }
        
        // Count limbs (horizontal-ish lines)
        let limbCount = paths.filter { path in
            let pathBounds = path.boundingBox
            return pathBounds.width > pathBounds.height && pathBounds.width > 20
        }.count
        
        // Stick figure: main body + 2-4 limbs
        let validPathCount = paths.count >= 3 && paths.count <= 8
        let result = hasMainBody && limbCount >= 2 && validPathCount
        
        if result {
            print("  - Main body: ✅")
            print("  - Limb count: \(limbCount)")
            print("  - Valid path count: \(validPathCount)")
        }
        
        return result
    }
    
    private func detectBall(_ paths: [DrawingPath], aspectRatio: Double) -> Bool {
        // Simple shapes with roughly square bounds
        guard paths.count <= 3 && aspectRatio > 0.6 && aspectRatio < 1.6 else {
            return false
        }
        
        // Check if main path looks circular
        if let mainPath = paths.max(by: { $0.points.count < $1.points.count }) {
            let isCircular = isPathCircular(mainPath)
            if isCircular {
                print("  - Circular path detected: ✅")
            }
            return isCircular
        }
        
        return false
    }
    
    private func detectBox(_ paths: [DrawingPath], aspectRatio: Double) -> Bool {
        guard paths.count >= 3 && paths.count <= 8 else { return false }
        
        // Count straight lines
        let straightLines = paths.filter { isPathStraight($0) }.count
        
        // Look for rectangular patterns
        let hasRectangularAspect = aspectRatio > 1.2 || aspectRatio < 0.8
        let result = straightLines >= 3 && hasRectangularAspect
        
        if result {
            print("  - Straight lines: \(straightLines)")
            print("  - Rectangular aspect: \(hasRectangularAspect)")
        }
        
        return result
    }
    
    private func detectAnimal(_ paths: [DrawingPath], bounds: CGRect, aspectRatio: Double) -> Bool {
        // Animals tend to be wider and have multiple body parts
        guard aspectRatio > 1.2 && paths.count >= 4 && paths.count <= 12 else {
            return false
        }
        
        // Look for body + multiple appendages
        let hasMainBody = paths.contains { path in
            let pathBounds = path.boundingBox
            return pathBounds.width > 30 && pathBounds.width > pathBounds.height
        }
        
        let appendageCount = paths.filter { path in
            let pathBounds = path.boundingBox
            let pathCenter = CGPoint(x: pathBounds.midX, y: pathBounds.midY)
            let relativeY = pathCenter.y - bounds.midY
            return relativeY > bounds.height * 0.2 // Lower parts (legs/tail)
        }.count
        
        let result = hasMainBody && appendageCount >= 2
        
        if result {
            print("  - Main body: \(hasMainBody)")
            print("  - Appendage count: \(appendageCount)")
        }
        
        return result
    }
    
    // MARK: - Helper Methods
    
    private func calculateDrawingBounds(_ paths: [DrawingPath]) -> CGRect {
        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        
        for path in paths {
            for point in path.points {
                minX = min(minX, point.x)
                maxX = max(maxX, point.x)
                minY = min(minY, point.y)
                maxY = max(maxY, point.y)
            }
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    private func isPathCircular(_ path: DrawingPath) -> Bool {
        guard path.points.count > 8 else { return false }
        
        // Calculate center
        let centerX = path.points.map { $0.x }.reduce(0, +) / CGFloat(path.points.count)
        let centerY = path.points.map { $0.y }.reduce(0, +) / CGFloat(path.points.count)
        let center = CGPoint(x: centerX, y: centerY)
        
        // Check if points are roughly equidistant from center
        let distances = path.points.map { point in
            sqrt(pow(point.x - center.x, 2) + pow(point.y - center.y, 2))
        }
        
        let avgDistance = distances.reduce(0, +) / CGFloat(distances.count)
        let variance = distances.map { pow($0 - avgDistance, 2) }.reduce(0, +) / CGFloat(distances.count)
        
        return variance < pow(avgDistance * 0.4, 2) && avgDistance > 15
    }
    
    private func isPathStraight(_ path: DrawingPath) -> Bool {
        guard path.points.count >= 2 else { return false }
        
        let first = path.points.first!
        let last = path.points.last!
        let dx = abs(last.x - first.x)
        let dy = abs(last.y - first.y)
        
        // Consider it straight if it's predominantly in one direction
        return (dx > dy * 2 && dx > 20) || (dy > dx * 2 && dy > 20)
    }
}
