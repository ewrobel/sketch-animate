//
//  PreservingAnimator.swift
//  SketchAnimate
//
//  Created by Emily Wrobel on 6/24/25.
//

import Foundation
import CoreGraphics

// MARK: - Animation that Preserves Original Drawing Structure

class PreservingAnimator {
    
    static func generateWalkingAnimation(originalPaths: [DrawingPath], totalFrames: Int) -> [AnimationFrame] {
        print("🚶 Generating walking animation while preserving original structure")
        
        // Analyze the drawing to understand its structure
        let analysis = analyzeDrawingStructure(originalPaths)
        
        var frames: [AnimationFrame] = []
        
        for frameIndex in 0..<totalFrames {
            let progress = Double(frameIndex) / Double(totalFrames)
            let walkCycle = (progress * 2).truncatingRemainder(dividingBy: 1.0)
            
            // Create animated paths by transforming the original paths
            let animatedPaths = animatePathsPreservingStructure(
                originalPaths: originalPaths,
                analysis: analysis,
                walkPhase: walkCycle,
                forwardOffset: progress * 300
            )
            
            frames.append(AnimationFrame(paths: animatedPaths, frameNumber: frameIndex))
        }
        
        return frames
    }
    
    // MARK: - Drawing Structure Analysis
    
    struct DrawingAnalysis {
        let bodyPathIndex: Int?
        let bodyBounds: CGRect
        let armPaths: [(index: Int, side: Side)]
        let legPaths: [(index: Int, side: Side)]
        let headPaths: [Int]
        let overallBounds: CGRect
    }
    
    enum Side {
        case left, right, unknown
    }
    
    private static func analyzeDrawingStructure(_ paths: [DrawingPath]) -> DrawingAnalysis {
        // Find overall bounds
        let overallBounds = calculateOverallBounds(paths)
        let centerX = overallBounds.midX
        let centerY = overallBounds.midY
        
        // Find the main body (longest vertical-ish path)
        var bodyPathIndex: Int?
        var maxBodyScore: CGFloat = 0
        var bodyBounds = CGRect.zero
        
        for (index, path) in paths.enumerated() {
            let bounds = path.boundingBox
            let verticalness = bounds.height / max(bounds.width, 1)
            let size = bounds.height
            let bodyScore = verticalness * size
            
            if verticalness > 1.2 && bodyScore > maxBodyScore {
                maxBodyScore = bodyScore
                bodyPathIndex = index
                bodyBounds = bounds
            }
        }
        
        // Classify remaining paths
        var armPaths: [(index: Int, side: Side)] = []
        var legPaths: [(index: Int, side: Side)] = []
        var headPaths: [Int] = []
        
        for (index, path) in paths.enumerated() {
            guard index != bodyPathIndex else { continue }
            
            let bounds = path.boundingBox
            let pathCenterY = bounds.midY
            let pathCenterX = bounds.midX
            
            // Determine if it's upper (arms/head) or lower (legs)
            let relativeY = pathCenterY - centerY
            
            if relativeY < -overallBounds.height * 0.2 {
                // Upper area - could be head or arms
                let horizontalness = bounds.width / max(bounds.height, 1)
                
                if horizontalness > 1.2 {
                    // Horizontal = arm
                    let side: Side = pathCenterX < centerX ? .left : .right
                    armPaths.append((index: index, side: side))
                } else {
                    // Could be head
                    headPaths.append(index)
                }
            } else if relativeY > overallBounds.height * 0.1 {
                // Lower area - legs
                let side: Side = pathCenterX < centerX ? .left : .right
                legPaths.append((index: index, side: side))
            } else {
                // Middle area - could be arms
                let horizontalness = bounds.width / max(bounds.height, 1)
                if horizontalness > 1.2 {
                    let side: Side = pathCenterX < centerX ? .left : .right
                    armPaths.append((index: index, side: side))
                }
            }
        }
        
        print("📊 Drawing analysis:")
        print("  - Body: index \(bodyPathIndex ?? -1)")
        print("  - Arms: \(armPaths.count) (\(armPaths.map { "\($0.index):\($0.side)" }.joined(separator: ", ")))")
        print("  - Legs: \(legPaths.count) (\(legPaths.map { "\($0.index):\($0.side)" }.joined(separator: ", ")))")
        print("  - Head: \(headPaths.count) (\(headPaths.map(String.init).joined(separator: ", ")))")
        
        return DrawingAnalysis(
            bodyPathIndex: bodyPathIndex,
            bodyBounds: bodyBounds,
            armPaths: armPaths,
            legPaths: legPaths,
            headPaths: headPaths,
            overallBounds: overallBounds
        )
    }
    
    // MARK: - Animation with Structure Preservation
    
    private static func animatePathsPreservingStructure(
        originalPaths: [DrawingPath],
        analysis: DrawingAnalysis,
        walkPhase: Double,
        forwardOffset: Double
    ) -> [DrawingPath] {
        
        var animatedPaths: [DrawingPath] = []
        
        // Calculate walking motion parameters
        let bodyBob = sin(walkPhase * 2 * .pi) * 8
        let bodySway = sin(walkPhase * 2 * .pi) * 3
        let leftLegSwing = sin(walkPhase * 2 * .pi) * 30
        let rightLegSwing = sin(walkPhase * 2 * .pi + .pi) * 30
        let leftArmSwing = sin(walkPhase * 2 * .pi + .pi) * 20  // Arms opposite to legs
        let rightArmSwing = sin(walkPhase * 2 * .pi) * 20
        
        for (index, originalPath) in originalPaths.enumerated() {
            var animatedPath = DrawingPath()
            
            // Determine what type of path this is and how to animate it
            let pathType = classifyPath(index: index, analysis: analysis)
            
            // Transform each point in the path
            for point in originalPath.points {
                var newPoint = point
                
                // Base movement - everyone moves forward
                newPoint.x += forwardOffset
                
                // Apply specific animations based on path type
                switch pathType {
                case .body:
                    // Body gets bob and sway
                    newPoint.x += bodySway
                    newPoint.y += bodyBob
                    
                case .head:
                    // Head follows body movement plus slight nod
                    newPoint.x += bodySway + forwardOffset
                    newPoint.y += bodyBob * 0.7
                    
                case .leftArm:
                    // Left arm swings
                    newPoint.x += bodySway + leftArmSwing
                    newPoint.y += bodyBob * 0.5
                    
                case .rightArm:
                    // Right arm swings opposite
                    newPoint.x += bodySway + rightArmSwing
                    newPoint.y += bodyBob * 0.5
                    
                case .leftLeg:
                    // Left leg swings and lifts
                    newPoint.x += bodySway + leftLegSwing
                    newPoint.y += bodyBob * 0.3
                    if leftLegSwing > 0 {
                        newPoint.y -= abs(leftLegSwing) * 0.2 // Lift when swinging forward
                    }
                    
                case .rightLeg:
                    // Right leg swings opposite
                    newPoint.x += bodySway + rightLegSwing
                    newPoint.y += bodyBob * 0.3
                    if rightLegSwing > 0 {
                        newPoint.y -= abs(rightLegSwing) * 0.2
                    }
                    
                case .other:
                    // Unknown paths just get basic movement
                    newPoint.x += bodySway
                    newPoint.y += bodyBob * 0.5
                }
                
                animatedPath.points.append(newPoint)
            }
            
            // Rebuild the path from the transformed points
            animatedPath.rebuildPath()
            animatedPaths.append(animatedPath)
        }
        
        return animatedPaths
    }
    
    // MARK: - Path Classification
    
    enum PathType {
        case body, head, leftArm, rightArm, leftLeg, rightLeg, other
    }
    
    private static func classifyPath(index: Int, analysis: DrawingAnalysis) -> PathType {
        // Check if this is the body
        if index == analysis.bodyPathIndex {
            return .body
        }
        
        // Check if this is a head
        if analysis.headPaths.contains(index) {
            return .head
        }
        
        // Check arms
        for armInfo in analysis.armPaths {
            if armInfo.index == index {
                return armInfo.side == .left ? .leftArm : .rightArm
            }
        }
        
        // Check legs
        for legInfo in analysis.legPaths {
            if legInfo.index == index {
                return legInfo.side == .left ? .leftLeg : .rightLeg
            }
        }
        
        return .other
    }
    
    // MARK: - Utility Functions
    
    private static func calculateOverallBounds(_ paths: [DrawingPath]) -> CGRect {
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
