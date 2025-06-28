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
    
    // Replace the detection methods in AIAnalysisService.swift with these improved versions:


    // Replace the problematic section in detectStickFigure function:

    private func detectStickFigure(_ paths: [DrawingPath], bounds: CGRect) -> Bool {
        print("🤔 Checking stick figure...")
        
        // Look for main body (vertical line)
        var bodyPathIndex: Int? = nil
        let bodyPaths = paths.enumerated().compactMap { (index, path) -> (Int, DrawingPath)? in
            let pathBounds = path.boundingBox
            let verticalness = pathBounds.height / max(pathBounds.width, 1)
            if verticalness > 1.5 && pathBounds.height > 40 {
                if bodyPathIndex == nil {
                    bodyPathIndex = index // Store the first body path index
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
            // Skip the body path by comparing indices instead of references
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
        
        print("  📊 Body paths: \(bodyPaths.count), Limbs: \(limbCount), Has head: \(hasHead)")
        print("  📊 Valid path count: \(validPathCount), Total paths: \(paths.count)")
        print("  🎯 Stick figure result: \(result)")
        
        // Bonus points for having a head
        return result && (limbCount >= 3 || hasHead)
    }
    // Replace the box detection methods in AIAnalysisService.swift with these improved versions:

    private func detectBox(_ paths: [DrawingPath], aspectRatio: Double) -> Bool {
        print("🤔 Checking box...")
        
        guard paths.count >= 1 && paths.count <= 6 else {
            print("  ❌ Wrong path count for box: \(paths.count)")
            return false
        }
        
        let bounds = calculateDrawingBounds(paths)
        
        // Check if overall shape is roughly rectangular
        let isRoughlyRectangular = aspectRatio > 0.4 && aspectRatio < 2.5 // More forgiving
        
        // Look for box-like characteristics
        var boxScore = 0
        
        // 1. Check for rectangular overall bounds
        if isRoughlyRectangular {
            boxScore += 2
            print("  ✅ Rectangular bounds (aspect: \(String(format: "%.2f", aspectRatio)))")
        }
        
        // 2. Check for paths that form sides of a rectangle
        let sideDetection = analyzeBoxSides(paths, bounds: bounds)
        boxScore += sideDetection.score
        
        // 3. Check if paths roughly outline a rectangular perimeter
        let perimeterScore = analyzeRectangularPerimeter(paths, bounds: bounds)
        boxScore += perimeterScore
        
        // 4. Bonus for having 4 distinct segments (like 4 sides)
        if paths.count == 4 {
            boxScore += 1
            print("  ✅ Has 4 paths (like 4 sides)")
        }
        
        // 5. Check for right-angle corners
        let cornerScore = analyzeBoxCorners(paths, bounds: bounds)
        boxScore += cornerScore
        
        let result = boxScore >= 4 // Need at least 4 points to be considered a box
        
        print("  📊 Box analysis:")
        print("    - Rectangular bounds: \(isRoughlyRectangular)")
        print("    - Side detection: \(sideDetection.score)/3")
        print("    - Perimeter score: \(perimeterScore)/2")
        print("    - Corner score: \(cornerScore)/2")
        print("    - Total score: \(boxScore)/8")
        print("  🎯 Box result: \(result)")
        
        return result
    }

    // Helper struct for side analysis
    private struct BoxSideAnalysis {
        let score: Int
        let topSides: Int
        let bottomSides: Int
        let leftSides: Int
        let rightSides: Int
    }

    private func analyzeBoxSides(_ paths: [DrawingPath], bounds: CGRect) -> BoxSideAnalysis {
        var topSides = 0
        var bottomSides = 0
        var leftSides = 0
        var rightSides = 0
        
        for path in paths {
            let pathBounds = path.boundingBox
            let pathCenter = CGPoint(x: pathBounds.midX, y: pathBounds.midY)
            
            // Check which side of the rectangle this path might represent
            let nearTop = pathCenter.y < bounds.minY + bounds.height * 0.3
            let nearBottom = pathCenter.y > bounds.maxY - bounds.height * 0.3
            let nearLeft = pathCenter.x < bounds.minX + bounds.width * 0.3
            let nearRight = pathCenter.x > bounds.maxX - bounds.width * 0.3
            
            // Check if path is roughly horizontal (for top/bottom)
            let isHorizontalish = pathBounds.width > pathBounds.height * 0.5
            
            // Check if path is roughly vertical (for left/right)
            let isVerticalish = pathBounds.height > pathBounds.width * 0.5
            
            if nearTop && isHorizontalish { topSides += 1 }
            if nearBottom && isHorizontalish { bottomSides += 1 }
            if nearLeft && isVerticalish { leftSides += 1 }
            if nearRight && isVerticalish { rightSides += 1 }
        }
        
        // Score based on how many sides we found
        var score = 0
        if topSides > 0 { score += 1 }
        if bottomSides > 0 { score += 1 }
        if leftSides > 0 { score += 1 }
        if rightSides > 0 { score += 1 }
        
        // Bonus if we have opposing sides
        if topSides > 0 && bottomSides > 0 { score += 1 }
        if leftSides > 0 && rightSides > 0 { score += 1 }
        
        print("    - Sides: T:\(topSides) B:\(bottomSides) L:\(leftSides) R:\(rightSides)")
        
        return BoxSideAnalysis(
            score: min(score, 3), // Cap at 3
            topSides: topSides,
            bottomSides: bottomSides,
            leftSides: leftSides,
            rightSides: rightSides
        )
    }

    private func analyzeRectangularPerimeter(_ paths: [DrawingPath], bounds: CGRect) -> Int {
        // Check if the paths roughly trace the perimeter of the bounding rectangle
        var perimeterCoverage = 0
        let tolerance: CGFloat = 30
        
        for path in paths {
            guard !path.points.isEmpty else { continue }
            
            let firstPoint = path.points.first!
            let lastPoint = path.points.last!
            
            // Check if path runs along any edge of the bounding box
            let runsAlongTop = abs(firstPoint.y - bounds.minY) < tolerance || abs(lastPoint.y - bounds.minY) < tolerance
            let runsAlongBottom = abs(firstPoint.y - bounds.maxY) < tolerance || abs(lastPoint.y - bounds.maxY) < tolerance
            let runsAlongLeft = abs(firstPoint.x - bounds.minX) < tolerance || abs(lastPoint.x - bounds.minX) < tolerance
            let runsAlongRight = abs(firstPoint.x - bounds.maxX) < tolerance || abs(lastPoint.x - bounds.maxX) < tolerance
            
            if runsAlongTop || runsAlongBottom || runsAlongLeft || runsAlongRight {
                perimeterCoverage += 1
            }
        }
        
        print("    - Perimeter coverage: \(perimeterCoverage)/\(paths.count) paths")
        
        return min(perimeterCoverage, 2) // Cap at 2 points
    }

    private func analyzeBoxCorners(_ paths: [DrawingPath], bounds: CGRect) -> Int {
        // Look for right-angle turns or corners
        var cornerScore = 0
        
        for path in paths {
            if hasRightAngleTurns(path) {
                cornerScore += 1
            }
        }
        
        print("    - Right-angle corners found: \(cornerScore)")
        
        return min(cornerScore, 2) // Cap at 2 points
    }

    private func hasRightAngleTurns(_ path: DrawingPath) -> Bool {
        let points = path.points
        guard points.count >= 3 else { return false }
        
        // Sample points to check for right angles
        let sampleIndices = stride(from: 0, to: points.count - 2, by: max(1, points.count / 8))
        
        for i in sampleIndices {
            guard i + 2 < points.count else { continue }
            
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[i + 2]
            
            // Calculate vectors
            let v1 = CGPoint(x: p2.x - p1.x, y: p2.y - p1.y)
            let v2 = CGPoint(x: p3.x - p2.x, y: p3.y - p2.y)
            
            // Calculate angle between vectors
            let dotProduct = v1.x * v2.x + v1.y * v2.y
            let magnitude1 = sqrt(v1.x * v1.x + v1.y * v1.y)
            let magnitude2 = sqrt(v2.x * v2.x + v2.y * v2.y)
            
            if magnitude1 > 0 && magnitude2 > 0 {
                let cosAngle = dotProduct / (magnitude1 * magnitude2)
                let angle = acos(max(-1, min(1, cosAngle))) // Clamp to valid range
                let angleDegrees = angle * 180 / .pi
                
                // Check if it's close to a right angle (90 degrees)
                if abs(angleDegrees - 90) < 30 { // Within 30 degrees of right angle
                    return true
                }
            }
        }
        
        return false
    }
    private func detectBall(_ paths: [DrawingPath], aspectRatio: Double) -> Bool {
        print("🤔 Checking ball...")
        
        // Simple shapes with roughly square bounds
        guard paths.count <= 3 && aspectRatio > 0.7 && aspectRatio < 1.4 else {
            print("  ❌ Wrong path count or aspect ratio for ball")
            return false
        }
        
        // Check if main path looks circular
        if let mainPath = paths.max(by: { $0.points.count < $1.points.count }) {
            let isCircular = isPathCircular(mainPath)
            print("  📊 Main path circular: \(isCircular), Points: \(mainPath.points.count)")
            print("  🎯 Ball result: \(isCircular)")
            return isCircular
        }
        
        return false
    }

    // Enhanced circular detection
    private func isPathCircular(_ path: DrawingPath) -> Bool {
        guard path.points.count > 12 else { return false } // More points needed for circle
        
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
        
        // Tighter variance check for better circle detection
        let isCircular = variance < pow(avgDistance * 0.25, 2) && avgDistance > 20
        
        print("    🔍 Circle analysis: avgDist=\(Int(avgDistance)), variance=\(Int(variance)), circular=\(isCircular)")
        
        return isCircular
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
