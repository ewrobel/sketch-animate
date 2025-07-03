import Foundation
import UIKit
import SwiftUI

// Simplified local analysis service focusing on human and ball detection
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
        
        print("🎯 AI analyzing drawing with \(drawingPaths.count) paths")
        
        // Use enhanced local detection
        let detectedType = performLocalAnalysis(drawingPaths)
        
        print("✅ AI analysis result: \(detectedType.displayName)")
        return detectedType
    }
    
    // MARK: - Enhanced Local Analysis
    
    private func performLocalAnalysis(_ paths: [DrawingPath]) -> ObjectType {
        guard !paths.isEmpty else { return .unknown }
        
        let bounds = calculateDrawingBounds(paths)
        let aspectRatio = bounds.width / bounds.height
        let totalPoints = paths.reduce(0) { $0 + $1.points.count }
        
        print("📊 AI Drawing analysis:")
        print("  - Paths: \(paths.count)")
        print("  - Total points: \(totalPoints)")
        print("  - Aspect ratio: \(String(format: "%.2f", aspectRatio))")
        print("  - Bounds: \(Int(bounds.width))x\(Int(bounds.height))")
        
        // Enhanced stick figure detection (priority since it's the main feature)
        if detectStickFigure(paths, bounds: bounds) {
            print("🎯 AI Detected: Human (stick figure)")
            return .human
        }
        
        // Enhanced ball detection
        if detectBall(paths, aspectRatio: aspectRatio) {
            print("🎯 AI Detected: Ball")
            return .ball
        }
        
        print("🎯 AI Detected: Unknown drawing")
        return .unknown
    }
    
    // MARK: - Detection Methods
    
    private func detectStickFigure(_ paths: [DrawingPath], bounds: CGRect) -> Bool {
        print("🤔 AI checking stick figure...")
        
        // Look for main body (vertical line)
        var bodyPathIndex: Int? = nil
        let bodyPaths = paths.enumerated().compactMap { (index, path) -> (Int, DrawingPath)? in
            let pathBounds = path.boundingBox
            let verticalness = pathBounds.height / max(pathBounds.width, 1)
            if verticalness > 1.5 && pathBounds.height > 40 {
                if bodyPathIndex == nil {
                    bodyPathIndex = index
                }
                return (index, path)
            }
            return nil
        }
        
        guard let mainBodyIndex = bodyPathIndex else {
            print("  ❌ No vertical body found")
            return false
        }
        
        // Count limbs (lines extending from body area) - excluding the body path by index
        let mainBodyBounds = paths[mainBodyIndex].boundingBox
        let limbCount = paths.enumerated().filter { (index, path) in
            guard index != mainBodyIndex else { return false }
            
            let pathBounds = path.boundingBox
            let pathCenter = CGPoint(x: pathBounds.midX, y: pathBounds.midY)
            
            // Check if this path extends from the body area
            let nearBody = abs(pathCenter.x - mainBodyBounds.midX) < mainBodyBounds.width + 50
            let isLimbLike = pathBounds.width > 20 || pathBounds.height > 20
            
            return nearBody && isLimbLike
        }.count
        
        // Check for head (circular path near top of body)
        let hasHead = paths.contains { path in
            let pathBounds = path.boundingBox
            let aspectRatio = pathBounds.width / pathBounds.height
            let nearTopOfBody = pathBounds.midY < mainBodyBounds.minY + 30
            return aspectRatio > 0.6 && aspectRatio < 1.6 && path.points.count > 8 && nearTopOfBody
        }
        
        let validPathCount = paths.count >= 3 && paths.count <= 8
        let result = bodyPaths.count >= 1 && limbCount >= 2 && validPathCount
        
        print("  📊 AI Analysis - Body paths: \(bodyPaths.count), Limbs: \(limbCount), Has head: \(hasHead)")
        print("  📊 Valid path count: \(validPathCount), Total paths: \(paths.count)")
        print("  🎯 AI Stick figure result: \(result)")
        
        // Bonus points for having a head
        return result && (limbCount >= 3 || hasHead)
    }
    
    private func detectBall(_ paths: [DrawingPath], aspectRatio: Double) -> Bool {
        print("🤔 AI checking ball...")
        
        // Simple shapes with roughly square bounds
        guard paths.count <= 3 && aspectRatio > 0.6 && aspectRatio < 1.5 else {
            print("  ❌ Wrong path count or aspect ratio for ball")
            return false
        }
        
        // Check if main path looks circular
        if let mainPath = paths.max(by: { $0.points.count < $1.points.count }) {
            let isCircular = isPathCircular(mainPath)
            print("  📊 AI Main path circular: \(isCircular), Points: \(mainPath.points.count)")
            print("  🎯 AI Ball result: \(isCircular)")
            return isCircular
        }
        
        return false
    }

    // Enhanced circular detection
    private func isPathCircular(_ path: DrawingPath) -> Bool {
        guard path.points.count > 15 else { return false }
        
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
        
        // More refined circle detection
        let hasGoodRadius = avgDistance > 25
        let hasLowVariance = variance < pow(avgDistance * 0.25, 2)
        let isCircular = hasGoodRadius && hasLowVariance
        
        print("    🔍 AI Circle analysis: avgDist=\(Int(avgDistance)), variance=\(Int(variance)), circular=\(isCircular)")
        
        return isCircular
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
}
