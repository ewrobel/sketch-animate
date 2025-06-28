//
//  ReliableSkeletalAnimator.swift
//  SketchAnimate
//
//  Created by Emily Wrobel on 6/27/25.
//

import Foundation
import CoreGraphics

// MARK: - Simplified Reliable Skeletal System

struct ReliableJoint {
    let id: String
    let originalPosition: CGPoint
    var currentPosition: CGPoint
    
    init(id: String, position: CGPoint) {
        self.id = id
        self.originalPosition = position
        self.currentPosition = position
    }
    
    mutating func moveTo(_ position: CGPoint) {
        self.currentPosition = position
    }
}

struct ReliableBone {
    let id: String
    let startJointId: String
    let endJointId: String
    let length: CGFloat
    let pathIndex: Int
    
    init(id: String, start: String, end: String, length: CGFloat, pathIndex: Int) {
        self.id = id
        self.startJointId = start
        self.endJointId = end
        self.length = length
        self.pathIndex = pathIndex
    }
}

class ReliableSkeletalAnimator {
    
    // MARK: - Create Skeleton with Guaranteed Connections
    
    static func createReliableSkeleton(from paths: [DrawingPath]) -> (joints: [String: ReliableJoint], bones: [ReliableBone], headPath: (path: DrawingPath, index: Int)?)? {
        
        print("🦴 Creating reliable skeleton from \(paths.count) paths")
        
        guard !paths.isEmpty else { return nil }
        
        // Find main body (longest vertical line)
        guard let bodyInfo = findMainBody(paths) else {
            print("❌ No main body found")
            return nil
        }
        
        let bodyPath = bodyInfo.path
        let bodyIndex = bodyInfo.index
        let bodyBounds = bodyPath.boundingBox
        
        print("✅ Found body: \(Int(bodyBounds.height))px tall at index \(bodyIndex)")
        
        // Find head (circular path)
        let headPath = findHeadPath(paths)
        if let head = headPath {
            print("✅ Found head at index \(head.index)")
        }
        
        // Create joints based on body
        var joints: [String: ReliableJoint] = [:]
        
        let bodyTop = bodyBounds.minY
        let bodyBottom = bodyBounds.maxY
        let bodyCenter = bodyBounds.midX
        let bodyHeight = bodyBounds.height
        
        // Main joints
        let hipPosition = CGPoint(x: bodyCenter, y: bodyBottom - bodyHeight * 0.1)
        let shoulderPosition = CGPoint(x: bodyCenter, y: bodyTop + bodyHeight * 0.15)
        let neckPosition = CGPoint(x: bodyCenter, y: bodyTop)
        
        joints["hip"] = ReliableJoint(id: "hip", position: hipPosition)
        joints["shoulder"] = ReliableJoint(id: "shoulder", position: shoulderPosition)
        joints["neck"] = ReliableJoint(id: "neck", position: neckPosition)
        
        // Head position
        let headPosition: CGPoint
        if let head = headPath {
            let headBounds = head.path.boundingBox
            headPosition = CGPoint(x: headBounds.midX, y: headBounds.midY)
        } else {
            headPosition = CGPoint(x: bodyCenter, y: bodyTop - 20)
        }
        joints["head"] = ReliableJoint(id: "head", position: headPosition)
        
        // Create bones
        var bones: [ReliableBone] = []
        
        // Main body bone
        bones.append(ReliableBone(
            id: "torso",
            start: "hip",
            end: "shoulder",
            length: bodyHeight * 0.75,
            pathIndex: bodyIndex
        ))
        
        // Find and classify limbs
        let limbs = classifyLimbs(paths, excluding: [bodyIndex], relativeTo: bodyBounds)
        
        for limb in limbs {
            // Add joint for limb end
            joints[limb.endJointId] = ReliableJoint(id: limb.endJointId, position: limb.endPosition)
            
            // Add joint for limb start if it doesn't exist
            if joints[limb.startJointId] == nil {
                joints[limb.startJointId] = ReliableJoint(id: limb.startJointId, position: limb.startPosition)
            }
            
            // Add bone
            bones.append(ReliableBone(
                id: limb.id,
                start: limb.startJointId,
                end: limb.endJointId,
                length: limb.length,
                pathIndex: limb.pathIndex
            ))
            
            print("✅ Added \(limb.id): \(limb.startJointId) → \(limb.endJointId)")
        }
        
        print("✅ Created skeleton: \(joints.count) joints, \(bones.count) bones")
        return (joints, bones, headPath)
    }
    
    // MARK: - Generate Walking Animation
    
    static func generateWalkingAnimation(
        joints: [String: ReliableJoint],
        bones: [ReliableBone],
        headPath: (path: DrawingPath, index: Int)?,
        originalPaths: [DrawingPath],
        totalFrames: Int
    ) -> [AnimationFrame] {
        
        print("🚶 Generating reliable walking animation")
        
        var frames: [AnimationFrame] = []
        
        for frameIndex in 0..<totalFrames {
            let progress = Double(frameIndex) / Double(totalFrames)
            let walkPhase = (progress * 2).truncatingRemainder(dividingBy: 1.0)
            
            // Animate joints
            let animatedJoints = animateJointsForWalking(
                joints,
                walkPhase: walkPhase,
                forwardOffset: progress * 200
            )
            
            // Convert to paths
            let animatedPaths = convertToPaths(
                joints: animatedJoints,
                bones: bones,
                headPath: headPath,
                originalPaths: originalPaths
            )
            
            frames.append(AnimationFrame(paths: animatedPaths, frameNumber: frameIndex))
            
            if frameIndex < 3 {
                debugFrame(joints: animatedJoints, frameNumber: frameIndex)
            }
        }
        
        return frames
    }
    
    // MARK: - Animation Logic
    
    // MARK: - Animation Logic (CORRECTED VERSION)
    // Replace the animateJointsForWalking function in your SkeletalAnimator.swift file

    private static func animateJointsForWalking(
        _ originalJoints: [String: ReliableJoint],
        walkPhase: Double,
        forwardOffset: Double
    ) -> [String: ReliableJoint] {
        
        var joints = originalJoints
        
        // Walking motion parameters
        let bodyBob = sin(walkPhase * 2 * .pi) * 6
        let bodySway = sin(walkPhase * 4 * .pi) * 2
        let leftLegSwing = sin(walkPhase * 2 * .pi) * 25
        let rightLegSwing = sin(walkPhase * 2 * .pi + .pi) * 25
        let leftArmSwing = sin(walkPhase * 2 * .pi + .pi) * 15
        let rightArmSwing = sin(walkPhase * 2 * .pi) * 15
        
        // 1. Move hip (root) - everything else follows from this
        if var hip = joints["hip"] {
            hip.moveTo(CGPoint(
                x: hip.originalPosition.x + forwardOffset + bodySway,
                y: hip.originalPosition.y + bodyBob
            ))
            joints["hip"] = hip
        }
        
        // 2. Move shoulder maintaining connection to hip
        if var shoulder = joints["shoulder"],
           let hip = joints["hip"] {
            shoulder.moveTo(CGPoint(
                x: hip.currentPosition.x + bodySway * 0.5,
                y: hip.currentPosition.y - 60 + bodyBob * 0.8 // -60 is approximate torso length
            ))
            joints["shoulder"] = shoulder
        }
        
        // 3. Move neck and head following shoulder
        if var neck = joints["neck"],
           let shoulder = joints["shoulder"] {
            neck.moveTo(CGPoint(
                x: shoulder.currentPosition.x,
                y: shoulder.currentPosition.y - 10
            ))
            joints["neck"] = neck
        }
        
        if var head = joints["head"],
           let neck = joints["neck"] {
            head.moveTo(CGPoint(
                x: neck.currentPosition.x + sin(walkPhase * 2 * .pi) * 1, // Slight head nod
                y: neck.currentPosition.y - 15 + sin(walkPhase * 2 * .pi) * 2
            ))
            joints["head"] = head
        }
        
        // 4. Move arms - NOW USING shoulder position
        if var leftHand = joints["hand_left"],
           let shoulder = joints["shoulder"] {
            leftHand.moveTo(CGPoint(
                x: shoulder.currentPosition.x - 30 + leftArmSwing,  // Connected to shoulder
                y: shoulder.currentPosition.y + 20 + leftArmSwing * 0.2
            ))
            joints["hand_left"] = leftHand
        }
        
        if var rightHand = joints["hand_right"],
           let shoulder = joints["shoulder"] {
            rightHand.moveTo(CGPoint(
                x: shoulder.currentPosition.x + 30 + rightArmSwing,  // Connected to shoulder
                y: shoulder.currentPosition.y + 20 + rightArmSwing * 0.2
            ))
            joints["hand_right"] = rightHand
        }
        
        // 5. Move legs - NOW USING hip position to maintain connection
        if var leftFoot = joints["foot_left"],
           let hip = joints["hip"] {
            leftFoot.moveTo(CGPoint(
                x: hip.currentPosition.x - 10 + leftLegSwing,  // Connected to hip
                y: hip.currentPosition.y + 50 + (leftLegSwing > 0 ? -abs(leftLegSwing) * 0.2 : 0)
            ))
            joints["foot_left"] = leftFoot
        }
        
        if var rightFoot = joints["foot_right"],
           let hip = joints["hip"] {
            rightFoot.moveTo(CGPoint(
                x: hip.currentPosition.x + 10 + rightLegSwing,  // Connected to hip
                y: hip.currentPosition.y + 50 + (rightLegSwing > 0 ? -abs(rightLegSwing) * 0.2 : 0)
            ))
            joints["foot_right"] = rightFoot
        }
        
        return joints
    }
    // MARK: - Convert to Paths
    
    private static func convertToPaths(
        joints: [String: ReliableJoint],
        bones: [ReliableBone],
        headPath: (path: DrawingPath, index: Int)?,
        originalPaths: [DrawingPath]
    ) -> [DrawingPath] {
        
        var animatedPaths = originalPaths
        
        // Update each bone path
        for bone in bones {
            guard bone.pathIndex < animatedPaths.count,
                  let startJoint = joints[bone.startJointId],
                  let endJoint = joints[bone.endJointId] else {
                continue
            }
            
            var newPath = DrawingPath()
            newPath.points = [startJoint.currentPosition, endJoint.currentPosition]
            newPath.rebuildPath()
            animatedPaths[bone.pathIndex] = newPath
        }
        
        // Update head path specially
        if let headInfo = headPath,
           let headJoint = joints["head"] {
            
            let originalHeadBounds = headInfo.path.boundingBox
            let originalCenter = CGPoint(x: originalHeadBounds.midX, y: originalHeadBounds.midY)
            
            let deltaX = headJoint.currentPosition.x - originalCenter.x
            let deltaY = headJoint.currentPosition.y - originalCenter.y
            
            var newHeadPath = DrawingPath()
            for point in headInfo.path.points {
                newHeadPath.points.append(CGPoint(x: point.x + deltaX, y: point.y + deltaY))
            }
            newHeadPath.rebuildPath()
            animatedPaths[headInfo.index] = newHeadPath
        }
        
        return animatedPaths
    }
    
    // MARK: - Helper Methods
    
    private static func findMainBody(_ paths: [DrawingPath]) -> (path: DrawingPath, index: Int)? {
        var bestIndex = 0
        var bestScore: CGFloat = 0
        
        for (index, path) in paths.enumerated() {
            let bounds = path.boundingBox
            let verticalness = bounds.height / max(bounds.width, 1)
            
            if verticalness > 1.2 && bounds.height > 40 {
                let score = verticalness * bounds.height
                if score > bestScore {
                    bestScore = score
                    bestIndex = index
                }
            }
        }
        
        return bestScore > 0 ? (paths[bestIndex], bestIndex) : nil
    }
    
    private static func findHeadPath(_ paths: [DrawingPath]) -> (path: DrawingPath, index: Int)? {
        for (index, path) in paths.enumerated() {
            let bounds = path.boundingBox
            let aspectRatio = bounds.width / bounds.height
            
            if aspectRatio > 0.6 && aspectRatio < 1.6 && path.points.count > 8 {
                return (path, index)
            }
        }
        return nil
    }
    
    struct LimbInfo {
        let id: String
        let startJointId: String
        let endJointId: String
        let startPosition: CGPoint
        let endPosition: CGPoint
        let length: CGFloat
        let pathIndex: Int
    }
    
    private static func classifyLimbs(_ paths: [DrawingPath], excluding excludedIndices: [Int], relativeTo bodyBounds: CGRect) -> [LimbInfo] {
        var limbs: [LimbInfo] = []
        
        for (index, path) in paths.enumerated() {
            guard !excludedIndices.contains(index) else { continue }
            
            let bounds = path.boundingBox
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            let length = sqrt(pow(bounds.width, 2) + pow(bounds.height, 2))
            
            let relativeX = center.x - bodyBounds.midX
            let relativeY = center.y - bodyBounds.midY
            
            // Classify limb based on position
            if relativeY < -bodyBounds.height * 0.1 {
                // Upper area - arms
                if relativeX < 0 {
                    limbs.append(LimbInfo(
                        id: "left_arm",
                        startJointId: "shoulder",
                        endJointId: "hand_left",
                        startPosition: CGPoint(x: bodyBounds.midX - 10, y: bodyBounds.minY + bodyBounds.height * 0.15),
                        endPosition: CGPoint(x: bounds.minX, y: bounds.midY),
                        length: length,
                        pathIndex: index
                    ))
                } else {
                    limbs.append(LimbInfo(
                        id: "right_arm",
                        startJointId: "shoulder",
                        endJointId: "hand_right",
                        startPosition: CGPoint(x: bodyBounds.midX + 10, y: bodyBounds.minY + bodyBounds.height * 0.15),
                        endPosition: CGPoint(x: bounds.maxX, y: bounds.midY),
                        length: length,
                        pathIndex: index
                    ))
                }
            } else if relativeY > bodyBounds.height * 0.1 {
                // Lower area - legs
                if relativeX < 0 {
                    limbs.append(LimbInfo(
                        id: "left_leg",
                        startJointId: "hip",
                        endJointId: "foot_left",
                        startPosition: CGPoint(x: bodyBounds.midX - 5, y: bodyBounds.maxY - bodyBounds.height * 0.1),
                        endPosition: CGPoint(x: bounds.midX, y: bounds.maxY),
                        length: length,
                        pathIndex: index
                    ))
                } else {
                    limbs.append(LimbInfo(
                        id: "right_leg",
                        startJointId: "hip",
                        endJointId: "foot_right",
                        startPosition: CGPoint(x: bodyBounds.midX + 5, y: bodyBounds.maxY - bodyBounds.height * 0.1),
                        endPosition: CGPoint(x: bounds.midX, y: bounds.maxY),
                        length: length,
                        pathIndex: index
                    ))
                }
            }
        }
        
        return limbs
    }
    
    private static func debugFrame(joints: [String: ReliableJoint], frameNumber: Int) {
        print("🦴 Frame \(frameNumber):")
        for (id, joint) in joints {
            print("  \(id): (\(Int(joint.currentPosition.x)), \(Int(joint.currentPosition.y)))")
        }
    }
}
