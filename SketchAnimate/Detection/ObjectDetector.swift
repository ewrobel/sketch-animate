import Foundation
import CoreGraphics

class ObjectDetector {
    
    static func detectObject(from paths: [DrawingPath]) -> ObjectType {
        guard !paths.isEmpty else { return .unknown }
        
        let bounds = calculateDrawingBounds(paths)
        let aspectRatio = bounds.height > 0 ? bounds.width / bounds.height : 1.0
        
        print("🔍 Object Detection Analysis:")
        print("  - Paths: \(paths.count)")
        print("  - Aspect ratio: \(String(format: "%.2f", aspectRatio))")
        print("  - Bounds: \(Int(bounds.width))x\(Int(bounds.height))")
        
        // Detect human/stick figure (prioritize this since it's the main feature)
        if detectStickFigure(paths) {
            print("✅ Detected: Human (stick figure)")
            return .human
        }
        
        // Detect ball/circle
        if detectBall(paths, aspectRatio: aspectRatio) {
            print("✅ Detected: Ball")
            return .ball
        }
        
        // Default to unknown for all other drawings
        print("✅ Detected: Unknown drawing")
        return .unknown
    }
    
    // MARK: - Detection Methods
    
    private static func detectStickFigure(_ paths: [DrawingPath]) -> Bool {
        print("🤔 Checking for stick figure...")
        
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
        
        // Count limbs (lines extending from body area) - excluding the body path
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
        
        // Check for head (circular path near top of body) - MORE FLEXIBLE
        let hasHead = paths.contains { path in
            let pathBounds = path.boundingBox
            let aspectRatio = pathBounds.width / pathBounds.height
            let nearTopOfBody = pathBounds.midY < mainBodyBounds.minY + 50 // More generous
            let isHeadSized = pathBounds.width > 15 && pathBounds.height > 15 // Minimum size
            let isReasonablyRound = aspectRatio > 0.4 && aspectRatio < 2.5 // More flexible
            return isReasonablyRound && nearTopOfBody && isHeadSized && path.points.count > 5 // Fewer points needed
        }
        
        // Also check for facial features (eyes, mouth) as head indicators
        let hasFacialFeatures = paths.filter { path in
            let pathBounds = path.boundingBox
            let isSmallFeature = pathBounds.width < 20 && pathBounds.height < 20
            let isInHeadArea = pathBounds.midY < mainBodyBounds.minY + 60
            return isSmallFeature && isInHeadArea
        }.count >= 2 // At least 2 small features (eyes, mouth, etc.)
        
        let validPathCount = paths.count >= 3 && paths.count <= 12 // Allow more paths for faces
        let result = bodyPaths.count >= 1 && limbCount >= 2 && validPathCount
        
        print("  📊 Body paths: \(bodyPaths.count), Limbs: \(limbCount)")
        print("  📊 Has head: \(hasHead), Facial features: \(hasFacialFeatures)")
        print("  📊 Valid path count: \(validPathCount), Total paths: \(paths.count)")
        print("  🎯 Stick figure result: \(result)")
        
        // Accept if has basic structure, bonus for head or facial features
        return result && (limbCount >= 3 || hasHead || hasFacialFeatures)
    }
    
    private static func detectBall(_ paths: [DrawingPath], aspectRatio: Double) -> Bool {
        print("🤔 Checking for ball...")
        
        // Simple shapes with roughly square bounds
        guard paths.count <= 3 && aspectRatio > 0.6 && aspectRatio < 1.5 else {
            print("  ❌ Wrong path count (\(paths.count)) or aspect ratio (\(String(format: "%.2f", aspectRatio))) for ball")
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
    private static func isPathCircular(_ path: DrawingPath) -> Bool {
        guard path.points.count > 15 else {
            print("    ❌ Too few points for circle: \(path.points.count)")
            return false
        }
        
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
        
        // Circle detection criteria
        let hasGoodRadius = avgDistance > 25 // Minimum radius
        let hasLowVariance = variance < pow(avgDistance * 0.3, 2)
        let isCircular = hasGoodRadius && hasLowVariance
        
        print("    🔍 Circle analysis:")
        print("      - Avg radius: \(Int(avgDistance))")
        print("      - Variance: \(Int(variance))")
        print("      - Good radius: \(hasGoodRadius)")
        print("      - Low variance: \(hasLowVariance)")
        print("      - Is circular: \(isCircular)")
        
        return isCircular
    }
    
    // MARK: - Helper Methods
    
    private static func calculateDrawingBounds(_ paths: [DrawingPath]) -> CGRect {
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
    
    // MARK: - Debug Info
    
    static func getDetectionInfo(from paths: [DrawingPath]) -> String {
        let bounds = calculateDrawingBounds(paths)
        let aspectRatio = bounds.width / bounds.height
        
        let verticalPaths = paths.filter { path in
            let pathBounds = path.boundingBox
            let verticalness = pathBounds.height / max(pathBounds.width, 1)
            return verticalness > 1.5 && pathBounds.height > 40
        }
        
        let horizontalPaths = paths.filter { path in
            let pathBounds = path.boundingBox
            let horizontalness = pathBounds.width / max(pathBounds.height, 1)
            return horizontalness > 1.5 && pathBounds.width > 20
        }
        
        var info = "Detection Analysis:\n"
        info += "- Total paths: \(paths.count)\n"
        info += "- Vertical paths: \(verticalPaths.count)\n"
        info += "- Horizontal paths: \(horizontalPaths.count)\n"
        info += "- Aspect ratio: \(String(format: "%.2f", aspectRatio))\n"
        info += "- Bounds: \(Int(bounds.width))x\(Int(bounds.height))\n"
        
        // Add path details
        for (index, path) in paths.enumerated() {
            let bounds = path.boundingBox
            info += "- Path \(index): \(Int(bounds.width))x\(Int(bounds.height)), \(path.points.count) points\n"
        }
        
        return info
    }
}
