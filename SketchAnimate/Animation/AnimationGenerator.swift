import Foundation
import CoreGraphics

class AnimationGenerator {
    
    static func generateAnimation(
        for animationType: AnimationType,
        objectType: ObjectType,
        paths: [DrawingPath]
    ) -> [AnimationFrame] {
        
        print("🎬 Generating \(animationType.displayName) animation for \(objectType.displayName)")
        
        let frameRate = 10 // 10 FPS for smooth but manageable animation
        let totalFrames = Int(animationType.duration * Double(frameRate))
        
        print("📽️ Creating \(totalFrames) frames at \(frameRate) FPS")
        
        let frames: [AnimationFrame]
        
        switch animationType {
        case .walk:
            // Try reliable skeletal animation
            if let skeletonData = ReliableSkeletalAnimator.createReliableSkeleton(from: paths) {
                frames = ReliableSkeletalAnimator.generateWalkingAnimation(
                    joints: skeletonData.joints,
                    bones: skeletonData.bones,
                    headPath: skeletonData.headPath,
                    originalPaths: paths,
                    totalFrames: totalFrames
                )
            } else {
                // Fallback to path-based
                frames = generateWalkAnimation(paths: paths, totalFrames: totalFrames)
            }
        case .jump:
            frames = generateJumpAnimation(paths: paths, totalFrames: totalFrames)
        case .wave:
            frames = generateWaveAnimation(paths: paths, totalFrames: totalFrames)
        case .bounce:
            frames = generateBounceAnimation(paths: paths, totalFrames: totalFrames)
        case .roll:
            frames = generateRollAnimation(paths: paths, totalFrames: totalFrames)
        case .open:
            frames = generateOpenAnimation(paths: paths, totalFrames: totalFrames)
        case .shake:
            frames = generateShakeAnimation(paths: paths, totalFrames: totalFrames)
        case .wag:
            frames = generateWagAnimation(paths: paths, totalFrames: totalFrames)
        case .float:
            frames = generateFloatAnimation(paths: paths, totalFrames: totalFrames)
        case .spin:
            frames = generateSpinAnimation(paths: paths, totalFrames: totalFrames)
        }
        
        print("✅ Generated \(frames.count) animation frames")
        return frames
    }
    
    // MARK: - Walk Animation
    
    private static func generateWalkAnimation(paths: [DrawingPath], totalFrames: Int) -> [AnimationFrame] {
        var frames: [AnimationFrame] = []
        let bounds = calculateBounds(paths)
        
        for frameIndex in 0..<totalFrames {
            let progress = Double(frameIndex) / Double(totalFrames)
            let walkCycle = (progress * 4).truncatingRemainder(dividingBy: 1.0) // 4 complete walk cycles
            
            // Forward movement across screen
            let forwardOffset = progress * 300
            
            // Walking motion
            let bodyBob = sin(walkCycle * 2 * .pi) * 8
            let legSwing = sin(walkCycle * 2 * .pi) * 25
            let armSwing = sin(walkCycle * 2 * .pi + .pi) * 15 // Arms opposite to legs
            
            var animatedPaths: [DrawingPath] = []
            
            for originalPath in paths {
                var newPath = DrawingPath()
                let pathType = classifyPath(originalPath, allPaths: paths, bounds: bounds)
                
                for point in originalPath.points {
                    var newPoint = point
                    
                    // Base movement - everyone moves forward
                    newPoint.x += forwardOffset
                    
                    // Apply animation based on path type
                    switch pathType {
                    case .body:
                        newPoint.y += bodyBob
                        
                    case .leftLeg:
                        newPoint.x += legSwing
                        if legSwing > 0 { // Lift leg when swinging forward
                            newPoint.y -= abs(legSwing) * 0.3
                        }
                        
                    case .rightLeg:
                        newPoint.x -= legSwing
                        if legSwing < 0 { // Opposite leg
                            newPoint.y -= abs(legSwing) * 0.3
                        }
                        
                    case .leftArm:
                        newPoint.x += armSwing
                        newPoint.y += bodyBob * 0.5
                        
                    case .rightArm:
                        newPoint.x -= armSwing
                        newPoint.y += bodyBob * 0.5
                        
                    case .head:
                        newPoint.y += bodyBob * 0.7
                        
                    case .other:
                        newPoint.y += bodyBob * 0.3
                    }
                    
                    newPath.points.append(newPoint)
                }
                
                newPath.rebuildPath()
                animatedPaths.append(newPath)
            }
            
            frames.append(AnimationFrame(paths: animatedPaths, frameNumber: frameIndex))
        }
        
        return frames
    }
    
    // MARK: - Bounce Animation

    private static func generateBounceAnimation(paths: [DrawingPath], totalFrames: Int) -> [AnimationFrame] {
        var frames: [AnimationFrame] = []
        let bounds = calculateBounds(paths)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        
        // Define the ground level (near bottom of drawing area)
        let groundLevel = bounds.maxY + 50 // Just below the drawing
        let originalBottomY = bounds.maxY  // Bottom of the original drawing
        
        // Maximum bounce height (should not go above original position)
        let maxBounceHeight = min(bounds.height * 3.5, 200) // Limit bounce height
        
        print("🏀 Bounce setup: ground=\(Int(groundLevel)), original=\(Int(originalBottomY)), maxHeight=\(Int(maxBounceHeight))")
        
        for frameIndex in 0..<totalFrames {
            let progress = Double(frameIndex) / Double(totalFrames)
            let bouncePhase = (progress * 3).truncatingRemainder(dividingBy: 1.0) // 3 bounces
            
            // Physics-based bounce motion
            let bounceProgress = bouncePhase
            var bounceHeight: CGFloat
            
            if bounceProgress <= 0.5 {
                // Going up (first half of bounce)
                let upProgress = bounceProgress * 2 // 0 to 1
                bounceHeight = sin(upProgress * .pi) * maxBounceHeight
            } else {
                // Coming down (second half of bounce)
                let downProgress = (bounceProgress - 0.5) * 2 // 0 to 1
                bounceHeight = sin((1 - downProgress) * .pi) * maxBounceHeight
            }
            
            // Calculate vertical offset from original position
            let verticalOffset = -(bounceHeight) // Negative because we want to go up
            
            // Squash and stretch effect
            let heightFactor = 1.0 - (bounceHeight / maxBounceHeight) * 0.3 // Squash when on ground
            let widthFactor = 1.0 + (bounceHeight / maxBounceHeight) * 0.2   // Stretch when bouncing
            
            var animatedPaths: [DrawingPath] = []
            
            for originalPath in paths {
                var newPath = DrawingPath()
                
                for point in originalPath.points {
                    var newPoint = point
                    
                    // Apply vertical movement (bounce)
                    newPoint.y = point.y + verticalOffset
                    
                    // Apply squash and stretch relative to center
                    let relativeX = point.x - center.x
                    let relativeY = point.y - center.y
                    
                    newPoint.x = center.x + relativeX * widthFactor
                    newPoint.y = (center.y + verticalOffset) + relativeY * heightFactor
                    
                    // Ensure we don't go below ground level
                    newPoint.y = min(newPoint.y, groundLevel - 10)
                    
                    newPath.points.append(newPoint)
                }
                
                newPath.rebuildPath()
                animatedPaths.append(newPath)
            }
            
            frames.append(AnimationFrame(paths: animatedPaths, frameNumber: frameIndex))
            
            // Debug first few frames
            if frameIndex < 5 {
                let bottomY = animatedPaths.first?.points.map { $0.y }.max() ?? 0
                print("Frame \(frameIndex): bounceHeight=\(Int(bounceHeight)), bottomY=\(Int(bottomY))")
            }
        }
        
        return frames
    }
    
    // MARK: - Float Animation
    
    private static func generateFloatAnimation(paths: [DrawingPath], totalFrames: Int) -> [AnimationFrame] {
        var frames: [AnimationFrame] = []
        
        for frameIndex in 0..<totalFrames {
            let progress = Double(frameIndex) / Double(totalFrames)
            
            let floatX = sin(progress * 2 * .pi) * 30
            let floatY = cos(progress * 3 * .pi) * 20
            let rotation = sin(progress * .pi) * 0.1
            
            let bounds = calculateBounds(paths)
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            
            var animatedPaths: [DrawingPath] = []
            
            for originalPath in paths {
                var newPath = DrawingPath()
                
                for point in originalPath.points {
                    var newPoint = point
                    
                    // Apply rotation around center
                    let relativeX = point.x - center.x
                    let relativeY = point.y - center.y
                    
                    newPoint.x = center.x + relativeX * cos(rotation) - relativeY * sin(rotation) + floatX
                    newPoint.y = center.y + relativeX * sin(rotation) + relativeY * cos(rotation) + floatY
                    
                    newPath.points.append(newPoint)
                }
                
                newPath.rebuildPath()
                animatedPaths.append(newPath)
            }
            
            frames.append(AnimationFrame(paths: animatedPaths, frameNumber: frameIndex))
        }
        
        return frames
    }
    
    // MARK: - Simple Animations
    
    private static func generateJumpAnimation(paths: [DrawingPath], totalFrames: Int) -> [AnimationFrame] {
        var frames: [AnimationFrame] = []
        
        for frameIndex in 0..<totalFrames {
            let progress = Double(frameIndex) / Double(totalFrames)
            
            // Jump physics - parabolic motion
            let jumpHeight = sin(progress * .pi) * -100 // Negative for upward
            let stretch = progress < 0.5 ? 1.1 : 0.9 // Stretch up, squash down
            
            let bounds = calculateBounds(paths)
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            
            var animatedPaths: [DrawingPath] = []
            
            for originalPath in paths {
                var newPath = DrawingPath()
                
                for point in originalPath.points {
                    var newPoint = point
                    
                    let relativeY = point.y - center.y
                    newPoint.y = center.y + relativeY * stretch + jumpHeight
                    
                    newPath.points.append(newPoint)
                }
                
                newPath.rebuildPath()
                animatedPaths.append(newPath)
            }
            
            frames.append(AnimationFrame(paths: animatedPaths, frameNumber: frameIndex))
        }
        
        return frames
    }
    
    private static func generateWaveAnimation(paths: [DrawingPath], totalFrames: Int) -> [AnimationFrame] {
        var frames: [AnimationFrame] = []
        let bounds = calculateBounds(paths)
        
        // Identify which path is likely the arm to wave
        let armPathIndex = findWavingArm(paths, bounds: bounds)
        
        for frameIndex in 0..<totalFrames {
            let progress = Double(frameIndex) / Double(totalFrames)
            let waveMotion = sin(progress * 8 * .pi) * 25 // Faster waving
            let waveUpDown = sin(progress * 8 * .pi) * 15
            
            var animatedPaths: [DrawingPath] = []
            
            for (index, originalPath) in paths.enumerated() {
                var newPath = DrawingPath()
                
                if index == armPathIndex {
                    // This is the waving arm - animate it
                    for point in originalPath.points {
                        let newPoint = CGPoint(
                            x: point.x + waveMotion,
                            y: point.y + waveUpDown
                        )
                        newPath.points.append(newPoint)
                    }
                } else {
                    // All other body parts stay still
                    newPath.points = originalPath.points
                }
                
                newPath.rebuildPath()
                animatedPaths.append(newPath)
            }
            
            frames.append(AnimationFrame(paths: animatedPaths, frameNumber: frameIndex))
        }
        
        return frames
    }

    // Helper function to identify which path should wave
    private static func findWavingArm(_ paths: [DrawingPath], bounds: CGRect) -> Int {
        var bestArmIndex = 0
        var bestArmScore: CGFloat = 0
        
        for (index, path) in paths.enumerated() {
            let pathBounds = path.boundingBox
            let pathCenter = CGPoint(x: pathBounds.midX, y: pathBounds.midY)
            
            // Look for horizontal-ish lines in the upper area
            let isHorizontal = pathBounds.width > pathBounds.height
            let isInUpperArea = pathCenter.y < bounds.midY
            let isOnRightSide = pathCenter.x > bounds.midX // Right arm waves
            let hasGoodLength = pathBounds.width > 30
            
            var score: CGFloat = 0
            if isHorizontal { score += 3 }
            if isInUpperArea { score += 2 }
            if isOnRightSide { score += 1 }
            if hasGoodLength { score += 1 }
            
            if score > bestArmScore {
                bestArmScore = score
                bestArmIndex = index
            }
        }
        
        print("🤚 Wave animation will move path \(bestArmIndex) (score: \(bestArmScore))")
        return bestArmIndex
    }
    
    private static func generateRollAnimation(paths: [DrawingPath], totalFrames: Int) -> [AnimationFrame] {
        return generateSimpleAnimation(paths: paths, totalFrames: totalFrames) { progress, point, center in
            let rotation = progress * 2 * .pi
            let relativeX = point.x - center.x
            let relativeY = point.y - center.y
            
            return CGPoint(
                x: center.x + relativeX * cos(rotation) - relativeY * sin(rotation) + progress * 200,
                y: center.y + relativeX * sin(rotation) + relativeY * cos(rotation)
            )
        }
    }
    
    private static func generateOpenAnimation(paths: [DrawingPath], totalFrames: Int) -> [AnimationFrame] {
        return generateSimpleAnimation(paths: paths, totalFrames: totalFrames) { progress, point, center in
            let openAmount = progress * 50
            return CGPoint(x: point.x, y: point.y - openAmount)
        }
    }
    
    private static func generateShakeAnimation(paths: [DrawingPath], totalFrames: Int) -> [AnimationFrame] {
        return generateSimpleAnimation(paths: paths, totalFrames: totalFrames) { progress, point, center in
            let shakeX = sin(progress * 20 * .pi) * 10
            let shakeY = cos(progress * 20 * .pi) * 5
            return CGPoint(x: point.x + shakeX, y: point.y + shakeY)
        }
    }
    
    private static func generateWagAnimation(paths: [DrawingPath], totalFrames: Int) -> [AnimationFrame] {
        return generateSimpleAnimation(paths: paths, totalFrames: totalFrames) { progress, point, center in
            let wagAmount = sin(progress * 8 * .pi) * 15
            return CGPoint(x: point.x + wagAmount, y: point.y)
        }
    }
    
    private static func generateSpinAnimation(paths: [DrawingPath], totalFrames: Int) -> [AnimationFrame] {
        return generateSimpleAnimation(paths: paths, totalFrames: totalFrames) { progress, point, center in
            let rotation = progress * 4 * .pi
            let relativeX = point.x - center.x
            let relativeY = point.y - center.y
            
            return CGPoint(
                x: center.x + relativeX * cos(rotation) - relativeY * sin(rotation),
                y: center.y + relativeX * sin(rotation) + relativeY * cos(rotation)
            )
        }
    }
    
    // MARK: - Helper Functions
    
    private static func generateSimpleAnimation(
        paths: [DrawingPath],
        totalFrames: Int,
        transform: (Double, CGPoint, CGPoint) -> CGPoint
    ) -> [AnimationFrame] {
        var frames: [AnimationFrame] = []
        let bounds = calculateBounds(paths)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        
        for frameIndex in 0..<totalFrames {
            let progress = Double(frameIndex) / Double(totalFrames)
            var animatedPaths: [DrawingPath] = []
            
            for originalPath in paths {
                var newPath = DrawingPath()
                
                for point in originalPath.points {
                    let newPoint = transform(progress, point, center)
                    newPath.points.append(newPoint)
                }
                
                newPath.rebuildPath()
                animatedPaths.append(newPath)
            }
            
            frames.append(AnimationFrame(paths: animatedPaths, frameNumber: frameIndex))
        }
        
        return frames
    }
    
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
    
    // MARK: - Path Classification
    
    enum PathType {
        case body, head, leftArm, rightArm, leftLeg, rightLeg, other
    }
    
    private static func classifyPath(_ path: DrawingPath, allPaths: [DrawingPath], bounds: CGRect) -> PathType {
        let pathBounds = path.boundingBox
        let pathCenter = CGPoint(x: pathBounds.midX, y: pathBounds.midY)
        
        // Find the main vertical path (body)
        let isMainVertical = pathBounds.height > pathBounds.width &&
                           pathBounds.height > 40 &&
                           allPaths.allSatisfy { $0.boundingBox.height <= pathBounds.height }
        
        if isMainVertical {
            return .body
        }
        
        // Classify based on position relative to drawing center
        let relativeX = pathCenter.x - bounds.midX
        let relativeY = pathCenter.y - bounds.midY
        
        if relativeY < -bounds.height * 0.3 {
            return .head
        } else if relativeY < -bounds.height * 0.1 {
            // Upper area - arms
            return relativeX < 0 ? .leftArm : .rightArm
        } else {
            // Lower area - legs
            return relativeX < 0 ? .leftLeg : .rightLeg
        }
    }
}
