//
//  JointBasedAnimator.swift
//  SketchAnimate
//
//  Created by Emily Wrobel on 6/24/25.
//

import Foundation
import CoreGraphics

// MARK: - Joint-Based Animation System

class JointBasedAnimator {
    
    struct AnimatedJoint {
        let name: String
        var position: CGPoint
        var originalPosition: CGPoint
        let connectedParts: [Int]
        
        init(from joint: Joint) {
            self.name = joint.name
            self.position = CGPoint(x: joint.x, y: joint.y)
            self.originalPosition = CGPoint(x: joint.x, y: joint.y)
            self.connectedParts = joint.connectedParts
        }
    }
    
    struct AnimatedBodyPart {
        let id: Int
        let type: BodyPartType
        let startJointName: String
        let endJointName: String
        let originalPathIndex: Int
        
        init(from bodyPart: BodyPart, pathIndex: Int) {
            self.id = bodyPart.id
            self.type = bodyPart.type
            self.startJointName = bodyPart.startJoint
            self.endJointName = bodyPart.endJoint
            self.originalPathIndex = pathIndex
        }
    }
    
    static func generateWalkingAnimation(
        originalPaths: [DrawingPath],
        aiAnalysis: DetailedAIAnalysis,
        totalFrames: Int
    ) -> [AnimationFrame] {
        
        print("🦴 Generating joint-based walking animation")
        print("Body parts: \(aiAnalysis.bodyParts.count)")
        print("Joints: \(aiAnalysis.joints.count)")
        
        // Create animated joints and body parts
        var animatedJoints: [String: AnimatedJoint] = [:]
        for joint in aiAnalysis.joints {
            animatedJoints[joint.name] = AnimatedJoint(from: joint)
        }
        
        var animatedBodyParts: [AnimatedBodyPart] = []
        for (index, bodyPart) in aiAnalysis.bodyParts.enumerated() {
            let pathIndex = min(index, originalPaths.count - 1) // Map to available paths
            animatedBodyParts.append(AnimatedBodyPart(from: bodyPart, pathIndex: pathIndex))
        }
        
        var frames: [AnimationFrame] = []
        
        for frameIndex in 0..<totalFrames {
            let progress = Double(frameIndex) / Double(totalFrames)
            let walkPhase = (progress * 2).truncatingRemainder(dividingBy: 1.0)
            
            // Animate joints starting from root (torso/hip)
            let frameJoints = animateJointsFromRoot(
                joints: animatedJoints,
                hierarchy: aiAnalysis.hierarchy,
                walkPhase: walkPhase,
                forwardOffset: progress * 300
            )
            
            // Generate paths from animated joints
            let animatedPaths = generatePathsFromJoints(
                originalPaths: originalPaths,
                bodyParts: animatedBodyParts,
                joints: frameJoints
            )
            
            frames.append(AnimationFrame(paths: animatedPaths, frameNumber: frameIndex))
            
            if frameIndex < 3 {
                print("Frame \(frameIndex) joint positions:")
                for (name, joint) in frameJoints {
                    print("  \(name): (\(Int(joint.position.x)), \(Int(joint.position.y)))")
                }
            }
        }
        
        return frames
    }
    
    // MARK: - Joint Animation from Root
    
    private static func animateJointsFromRoot(
        joints: [String: AnimatedJoint],
        hierarchy: Hierarchy,
        walkPhase: Double,
        forwardOffset: Double
    ) -> [String: AnimatedJoint] {
        
        var animatedJoints = joints
        
        // Step 1: Animate the root joint (usually hip or torso center)
        let rootJointName = findRootJoint(hierarchy: hierarchy, joints: joints)
        
        if var rootJoint = animatedJoints[rootJointName] {
            // Root movement - walking motion
            let bodyBob = sin(walkPhase * 2 * .pi) * 8
            let bodySway = sin(walkPhase * 2 * .pi) * 3
            
            rootJoint.position = CGPoint(
                x: rootJoint.originalPosition.x + forwardOffset + bodySway,
                y: rootJoint.originalPosition.y + bodyBob
            )
            
            animatedJoints[rootJointName] = rootJoint
            print("🏃 Root joint \(rootJointName) moved to (\(Int(rootJoint.position.x)), \(Int(rootJoint.position.y)))")
        }
        
        // Step 2: Propagate movement to connected joints
        animatedJoints = propagateJointMovement(
            joints: animatedJoints,
            hierarchy: hierarchy,
            walkPhase: walkPhase,
            rootJointName: rootJointName
        )
        
        return animatedJoints
    }
    
    private static func propagateJointMovement(
        joints: [String: AnimatedJoint],
        hierarchy: Hierarchy,
        walkPhase: Double,
        rootJointName: String
    ) -> [String: AnimatedJoint] {
        
        var result = joints
        
        // Define walking motions for different body parts
        let leftLegSwing = sin(walkPhase * 2 * .pi) * 30
        let rightLegSwing = sin(walkPhase * 2 * .pi + .pi) * 30
        let leftArmSwing = sin(walkPhase * 2 * .pi + .pi) * 20  // Arms opposite to legs
        let rightArmSwing = sin(walkPhase * 2 * .pi) * 20
        
        // Get root position for relative calculations
        guard let rootJoint = result[rootJointName] else { return result }
        let rootDelta = CGPoint(
            x: rootJoint.position.x - rootJoint.originalPosition.x,
            y: rootJoint.position.y - rootJoint.originalPosition.y
        )
        
        // Animate specific joints relative to root
        let jointAnimations: [(String, CGPoint)] = [
            ("shoulder_left", CGPoint(x: leftArmSwing * 0.5, y: 0)),
            ("shoulder_right", CGPoint(x: rightArmSwing * 0.5, y: 0)),
            ("hand_left", CGPoint(x: leftArmSwing, y: leftArmSwing * 0.3)),
            ("hand_right", CGPoint(x: rightArmSwing, y: rightArmSwing * 0.3)),
            ("hip_left", CGPoint(x: leftLegSwing * 0.2, y: 0)),
            ("hip_right", CGPoint(x: rightLegSwing * 0.2, y: 0)),
            ("foot_left", CGPoint(x: leftLegSwing, y: leftLegSwing > 0 ? -abs(leftLegSwing) * 0.3 : 0)),
            ("foot_right", CGPoint(x: rightLegSwing, y: rightLegSwing > 0 ? -abs(rightLegSwing) * 0.3 : 0))
        ]
        
        for (jointName, additionalMotion) in jointAnimations {
            if var joint = result[jointName] {
                joint.position = CGPoint(
                    x: joint.originalPosition.x + rootDelta.x + additionalMotion.x,
                    y: joint.originalPosition.y + rootDelta.y + additionalMotion.y
                )
                result[jointName] = joint
            }
        }
        
        // Neck and head follow body with slight delay
        if var neckJoint = result["neck"] {
            neckJoint.position = CGPoint(
                x: neckJoint.originalPosition.x + rootDelta.x + sin(walkPhase * 2 * .pi) * 2,
                y: neckJoint.originalPosition.y + rootDelta.y * 0.8
            )
            result["neck"] = neckJoint
        }
        
        if var headJoint = result["head"] {
            let headBob = sin(walkPhase * 2 * .pi + 0.2) * 3 // Slight delay
            headJoint.position = CGPoint(
                x: headJoint.originalPosition.x + rootDelta.x + sin(walkPhase * 2 * .pi) * 1,
                y: headJoint.originalPosition.y + rootDelta.y * 0.6 + headBob
            )
            result["head"] = headJoint
        }
        
        return result
    }
    
    // MARK: - Path Generation from Joints
    
    private static func generatePathsFromJoints(
        originalPaths: [DrawingPath],
        bodyParts: [AnimatedBodyPart],
        joints: [String: AnimatedJoint]
    ) -> [DrawingPath] {
        
        var animatedPaths = originalPaths // Start with originals
        
        for bodyPart in bodyParts {
            guard bodyPart.originalPathIndex < animatedPaths.count,
                  let startJoint = joints[bodyPart.startJointName],
                  let endJoint = joints[bodyPart.endJointName] else {
                continue
            }
            
            // Create new path from start joint to end joint
            var newPath = DrawingPath()
            
            // For body parts, we want smooth lines from joint to joint
            newPath.points = [startJoint.position, endJoint.position]
            newPath.rebuildPath()
            
            animatedPaths[bodyPart.originalPathIndex] = newPath
            
            print("🔗 \(bodyPart.type) path: (\(Int(startJoint.position.x)), \(Int(startJoint.position.y))) → (\(Int(endJoint.position.x)), \(Int(endJoint.position.y)))")
        }
        
        return animatedPaths
    }
    
    // MARK: - Helper Functions
    
    private static func findRootJoint(hierarchy: Hierarchy, joints: [String: AnimatedJoint]) -> String {
        // Try to find hip or torso-related joint as root
        let possibleRoots = ["hip", "torso", "center", "waist"]
        
        for rootName in possibleRoots {
            if joints[rootName] != nil {
                return rootName
            }
        }
        
        // If no standard root found, use the first joint
        return joints.keys.first ?? "hip"
    }
}
