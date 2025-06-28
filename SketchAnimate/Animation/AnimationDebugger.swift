import Foundation
import CoreGraphics

class AnimationDebugger {
    
    // MARK: - Drawing Analysis
    
    static func debugDrawingPaths(_ paths: [DrawingPath]) {
        print("\n🎨 === DRAWING ANALYSIS ===")
        print("Total paths: \(paths.count)")
        
        for (index, path) in paths.enumerated() {
            let bounds = path.boundingBox
            let firstPoint = path.points.first ?? CGPoint.zero
            let lastPoint = path.points.last ?? CGPoint.zero
            
            print("📏 Path \(index):")
            print("  - Points: \(path.points.count)")
            print("  - Bounds: \(Int(bounds.width))x\(Int(bounds.height)) at (\(Int(bounds.minX)), \(Int(bounds.minY)))")
            print("  - Start: (\(Int(firstPoint.x)), \(Int(firstPoint.y)))")
            print("  - End: (\(Int(lastPoint.x)), \(Int(lastPoint.y)))")
            print("  - Aspect: \(String(format: "%.2f", bounds.width / max(bounds.height, 1)))")
            
            // Classify this path
            if bounds.height > bounds.width && bounds.height > 40 {
                print("  - Type: VERTICAL (likely body)")
            } else if bounds.width > bounds.height && bounds.width > 20 {
                print("  - Type: HORIZONTAL (likely limb)")
            } else {
                print("  - Type: SMALL/OTHER")
            }
        }
    }
    
    // MARK: - Animation Frame Analysis
    
    static func debugAnimationFrame(_ frame: AnimationFrame, frameNumber: Int) {
        print("\n🎬 === FRAME \(frameNumber) ===")
        print("Paths in frame: \(frame.paths.count)")
        
        for (index, path) in frame.paths.enumerated() {
            if let first = path.points.first, let last = path.points.last {
                print("  Path \(index): (\(Int(first.x)), \(Int(first.y))) → (\(Int(last.x)), \(Int(last.y)))")
            }
        }
    }
    
    // MARK: - Walking Animation Debug
    
    static func debugWalkingMotion(walkPhase: Double, frameIndex: Int) {
        let leftLegSwing = sin(walkPhase * 2 * .pi) * 0.6
        let rightLegSwing = sin(walkPhase * 2 * .pi + .pi) * 0.6
        let leftArmSwing = sin(walkPhase * 2 * .pi + .pi) * 0.4
        let rightArmSwing = sin(walkPhase * 2 * .pi) * 0.4
        let bodyBob = sin(walkPhase * 2 * .pi) * 8
        
        if frameIndex % 10 == 0 { // Only log every 10th frame to avoid spam
            print("\n🚶 Frame \(frameIndex) - Walk Phase: \(String(format: "%.2f", walkPhase))")
            print("  Body bob: \(String(format: "%.1f", bodyBob))")
            print("  Left leg: \(String(format: "%.2f", leftLegSwing)) | Right leg: \(String(format: "%.2f", rightLegSwing))")
            print("  Left arm: \(String(format: "%.2f", leftArmSwing)) | Right arm: \(String(format: "%.2f", rightArmSwing))")
        }
    }
    
    // MARK: - Animation Comparison
    
    static func compareOriginalVsAnimated(original: [DrawingPath], animated: [AnimationFrame]) {
        print("\n🔄 === ORIGINAL vs ANIMATED COMPARISON ===")
        print("Original paths: \(original.count)")
        print("Animation frames: \(animated.count)")
        
        guard let firstFrame = animated.first else {
            print("❌ No animation frames to compare")
            return
        }
        
        print("First frame paths: \(firstFrame.paths.count)")
        
        for (index, (originalPath, animatedPath)) in zip(original, firstFrame.paths).enumerated() {
            let origFirst = originalPath.points.first ?? CGPoint.zero
            let animFirst = animatedPath.points.first ?? CGPoint.zero
            let origLast = originalPath.points.last ?? CGPoint.zero
            let animLast = animatedPath.points.last ?? CGPoint.zero
            
            print("Path \(index):")
            print("  Original: (\(Int(origFirst.x)), \(Int(origFirst.y))) → (\(Int(origLast.x)), \(Int(origLast.y)))")
            print("  Animated: (\(Int(animFirst.x)), \(Int(animFirst.y))) → (\(Int(animLast.x)), \(Int(animLast.y)))")
            
            let deltaStartX = abs(origFirst.x - animFirst.x)
            let deltaStartY = abs(origFirst.y - animFirst.y)
            let deltaEndX = abs(origLast.x - animLast.x)
            let deltaEndY = abs(origLast.y - animLast.y)
            
            print("  Delta: start(\(Int(deltaStartX)), \(Int(deltaStartY))) end(\(Int(deltaEndX)), \(Int(deltaEndY)))")
            
            if deltaStartX < 5 && deltaStartY < 5 && deltaEndX < 5 && deltaEndY < 5 {
                print("  ⚠️  NO MOVEMENT DETECTED!")
            }
        }
        
        // Check mid-animation frame for movement
        if animated.count > 10, let midFrame = animated[safe: 10] {
            print("\nFrame 10 comparison:")
            for (index, (originalPath, animatedPath)) in zip(original, midFrame.paths).enumerated() {
                let origFirst = originalPath.points.first ?? CGPoint.zero
                let animFirst = animatedPath.points.first ?? CGPoint.zero
                
                let deltaX = abs(origFirst.x - animFirst.x)
                let deltaY = abs(origFirst.y - animFirst.y)
                
                print("  Path \(index) movement: (\(Int(deltaX)), \(Int(deltaY)))")
            }
        }
    }
    
    // MARK: - Animation Quality Analysis
    
    static func analyzeAnimationQuality(_ frames: [AnimationFrame]) {
        print("\n📊 === ANIMATION QUALITY ANALYSIS ===")
        print("Total frames: \(frames.count)")
        
        guard !frames.isEmpty else {
            print("❌ No frames to analyze")
            return
        }
        
        // Check for consistent path count
        let pathCounts = frames.map { $0.paths.count }
        let minPaths = pathCounts.min() ?? 0
        let maxPaths = pathCounts.max() ?? 0
        
        if minPaths == maxPaths {
            print("✅ Consistent path count: \(minPaths)")
        } else {
            print("⚠️  Inconsistent path counts: \(minPaths) to \(maxPaths)")
        }
        
        // Check for movement
        if frames.count >= 2 {
            let firstFrame = frames[0]
            let lastFrame = frames[frames.count - 1]
            
            var totalMovement: CGFloat = 0
            
            for (firstPath, lastPath) in zip(firstFrame.paths, lastFrame.paths) {
                if let firstPoint = firstPath.points.first,
                   let lastPoint = lastPath.points.first {
                    let distance = sqrt(pow(lastPoint.x - firstPoint.x, 2) + pow(lastPoint.y - firstPoint.y, 2))
                    totalMovement += distance
                }
            }
            
            print("📏 Total movement across animation: \(Int(totalMovement))px")
            
            if totalMovement < 10 {
                print("⚠️  Very little movement detected!")
            } else if totalMovement > 500 {
                print("✅ Good amount of movement")
            } else {
                print("🔶 Moderate movement")
            }
        }
    }
    
    // MARK: - Object Detection Debug
    
    static func debugObjectDetection(_ paths: [DrawingPath], detectedType: ObjectType) {
        print("\n🎯 === OBJECT DETECTION DEBUG ===")
        print("Detected: \(detectedType.displayName)")
        print("Available animations: \(detectedType.animations.map { $0.displayName }.joined(separator: ", "))")
        
        let bounds = calculateBounds(paths)
        let aspectRatio = bounds.width / bounds.height
        
        print("📐 Drawing metrics:")
        print("  - Bounds: \(Int(bounds.width))x\(Int(bounds.height))")
        print("  - Aspect ratio: \(String(format: "%.2f", aspectRatio))")
        print("  - Path count: \(paths.count)")
        
        // Analyze path types
        let verticalPaths = paths.filter { $0.isVertical }.count
        let horizontalPaths = paths.filter { $0.isHorizontal }.count
        let otherPaths = paths.count - verticalPaths - horizontalPaths
        
        print("  - Vertical paths: \(verticalPaths)")
        print("  - Horizontal paths: \(horizontalPaths)")
        print("  - Other paths: \(otherPaths)")
        
        // Detection logic explanation
        switch detectedType {
        case .human:
            print("🚶 Human detection criteria:")
            print("  - Has vertical body: \(verticalPaths > 0)")
            print("  - Has limbs: \(horizontalPaths >= 2)")
            print("  - Reasonable path count: \(paths.count >= 3 && paths.count <= 8)")
            
        case .ball:
            print("⚽ Ball detection criteria:")
            print("  - Simple shape: \(paths.count <= 3)")
            print("  - Roughly square: \(aspectRatio > 0.6 && aspectRatio < 1.6)")
            
        case .box:
            print("📦 Box detection criteria:")
            print("  - Multiple straight lines: \(horizontalPaths + verticalPaths >= 3)")
            print("  - Rectangular aspect: \(aspectRatio > 1.2 || aspectRatio < 0.8)")
            
        case .animal:
            print("🐕 Animal detection criteria:")
            print("  - Wide shape: \(aspectRatio > 1.2)")
            print("  - Multiple parts: \(paths.count >= 4)")
            
        case .unknown:
            print("❓ Unknown - didn't match any criteria")
        }
    }
    
    // MARK: - Performance Debug
    
    static func debugAnimationPerformance(_ frames: [AnimationFrame], generationTime: TimeInterval) {
        print("\n⚡ === ANIMATION PERFORMANCE ===")
        print("Generation time: \(String(format: "%.2f", generationTime))s")
        print("Frame count: \(frames.count)")
        print("Average time per frame: \(String(format: "%.3f", generationTime / Double(frames.count)))s")
        
        let totalPoints = frames.reduce(0) { total, frame in
            total + frame.paths.reduce(0) { $0 + $1.points.count }
        }
        
        print("Total points across all frames: \(totalPoints)")
        print("Average points per frame: \(totalPoints / frames.count)")
        
        if generationTime > 2.0 {
            print("⚠️  Slow generation time")
        } else if generationTime < 0.5 {
            print("⚡ Very fast generation")
        } else {
            print("✅ Good generation time")
        }
    }
    
    // MARK: - Utility Methods
    
    private static func calculateBounds(_ paths: [DrawingPath]) -> CGRect {
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

// MARK: - Helper Extensions

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
