//
//  AnimationDebugger.swift
//  SketchAnimate
//
//  Created by Emily Wrobel on 6/24/25.
//
import Foundation
import CoreGraphics

class AnimationDebugger {
    
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
    
    static func debugSkeleton(_ skeleton: StickFigureSkeleton) {
        print("\n🦴 === SKELETON ANALYSIS ===")
        print("Joints: \(skeleton.joints.count)")
        print("Bones: \(skeleton.bones.count)")
        print("Root: \(skeleton.rootJointId)")
        
        print("\n🔗 Joints:")
        for (id, joint) in skeleton.joints.sorted(by: { $0.key < $1.key }) {
            print("  - \(id): (\(Int(joint.position.x)), \(Int(joint.position.y))) rot: \(String(format: "%.2f", joint.rotation))")
        }
        
        print("\n🦴 Bones:")
        for bone in skeleton.bones {
            print("  - \(bone.id): \(bone.startJointId) → \(bone.endJointId)")
            print("    Length: \(Int(bone.originalLength)), Angle: \(String(format: "%.2f", bone.originalAngle)), Path: \(bone.pathIndex)")
        }
    }
    
    static func debugAnimationFrame(_ frame: AnimationFrame, frameNumber: Int) {
        print("\n🎬 === FRAME \(frameNumber) ===")
        print("Paths in frame: \(frame.paths.count)")
        
        for (index, path) in frame.paths.enumerated() {
            if let first = path.points.first, let last = path.points.last {
                print("  Path \(index): (\(Int(first.x)), \(Int(first.y))) → (\(Int(last.x)), \(Int(last.y)))")
            }
        }
    }
    
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
    
    static func compareOriginalVsAnimated(original: [DrawingPath], animated: [AnimationFrame]) {
        print("\n🔄 === ORIGINAL vs ANIMATED COMPARISON ===")
        print("Original paths: \(original.count)")
        print("Animation frames: \(animated.count)")
        
        if let firstFrame = animated.first {
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
        }
        
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
    
    static func debugJointMovement(originalJoint: CGPoint, animatedJoint: CGPoint, jointName: String) {
        let deltaX = animatedJoint.x - originalJoint.x
        let deltaY = animatedJoint.y - originalJoint.y
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
        
        print("🔄 \(jointName): moved \(String(format: "%.1f", distance))px (\(Int(deltaX)), \(Int(deltaY)))")
    }
}

// Helper extension for safe array access
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
