import Foundation
import CoreGraphics

// MARK: - Reliable Joint and Bone Structures

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

// MARK: - Adaptive Skeletal Animator

class ReliableSkeletalAnimator {
    
    // MARK: - Create Adaptive Skeleton
    
    static func createReliableSkeleton(from paths: [DrawingPath]) -> (joints: [String: ReliableJoint], bones: [ReliableBone], headPath: (path: DrawingPath, index: Int)?)? {
        
        print("🦴 Creating ADAPTIVE skeleton from \(paths.count) paths")
        
        guard !paths.isEmpty else { return nil }
        
        // First, identify what we actually have
        let analysis = analyzePaths(paths)
        
        guard analysis.bodyIndex != nil else {
            print("❌ No body found - falling back to path-based animation")
            return nil
        }
        
        print("✅ Analysis complete:")
        print("  - Body: index \(analysis.bodyIndex!)")
        print("  - Head: \(analysis.headIndex != nil ? "index \(analysis.headIndex!)" : "none")")
        print("  - Neck: \(analysis.neckIndex != nil ? "index \(analysis.neckIndex!)" : "none")")
        print("  - Arms: \(analysis.armIndices.count)")
        print("  - Legs: \(analysis.legIndices.count)")
        
        // Create joints and bones based on what we actually found
        var joints: [String: ReliableJoint] = [:]
        var bones: [ReliableBone] = []
        
        let bodyPath = paths[analysis.bodyIndex!]
        let bodyBounds = bodyPath.boundingBox
        
        // Create basic skeleton joints
        let hipPosition = CGPoint(x: bodyBounds.midX, y: bodyBounds.maxY - 10)
        let shoulderPosition = CGPoint(x: bodyBounds.midX, y: bodyBounds.minY + 10)
        
        joints["hip"] = ReliableJoint(id: "hip", position: hipPosition)
        joints["shoulder"] = ReliableJoint(id: "shoulder", position: shoulderPosition)
        
        // Main body bone
        bones.append(ReliableBone(
            id: "torso",
            start: "hip",
            end: "shoulder",
            length: bodyBounds.height - 20,
            pathIndex: analysis.bodyIndex!
        ))
        
        // Handle neck specially - preserve it as its own path!
        if let neckIndex = analysis.neckIndex {
            let neckPath = paths[neckIndex]
            let neckBounds = neckPath.boundingBox
            
            // Create neck joints based on actual path endpoints
            let neckStart = neckPath.points.first ?? CGPoint(x: neckBounds.midX, y: neckBounds.maxY)
            let neckEnd = neckPath.points.last ?? CGPoint(x: neckBounds.midX, y: neckBounds.minY)
            
            joints["neck_start"] = ReliableJoint(id: "neck_start", position: neckStart)
            joints["neck_end"] = ReliableJoint(id: "neck_end", position: neckEnd)
            
            bones.append(ReliableBone(
                id: "neck",
                start: "neck_start",
                end: "neck_end",
                length: neckBounds.height,
                pathIndex: neckIndex  // IMPORTANT: Keep the original neck path
            ))
            
            print("✅ Added neck bone preserving original path at index \(neckIndex)")
        }
        
        // Add head positioning
        if let headIndex = analysis.headIndex {
            let headPath = paths[headIndex]
            let headBounds = headPath.boundingBox
            joints["head_center"] = ReliableJoint(id: "head_center", position: CGPoint(x: headBounds.midX, y: headBounds.midY))
            print("✅ Added head center joint")
        }
        
        // Add arms
        for (i, armIndex) in analysis.armIndices.enumerated() {
            let armPath = paths[armIndex]
            let armId = "arm_\(i)"
            let handId = "hand_\(i)"
            
            // Determine which end connects to body
            let startPoint = armPath.points.first ?? CGPoint.zero
            let endPoint = armPath.points.last ?? CGPoint.zero
            
            let startDistToBody = distanceToLine(point: startPoint, lineStart: shoulderPosition, lineEnd: hipPosition)
            let endDistToBody = distanceToLine(point: endPoint, lineStart: shoulderPosition, lineEnd: hipPosition)
            
            let (armStart, armEnd) = startDistToBody < endDistToBody ? (startPoint, endPoint) : (endPoint, startPoint)
            
            joints[handId] = ReliableJoint(id: handId, position: armEnd)
            
            bones.append(ReliableBone(
                id: armId,
                start: "shoulder",
                end: handId,
                length: sqrt(pow(armEnd.x - armStart.x, 2) + pow(armEnd.y - armStart.y, 2)),
                pathIndex: armIndex
            ))
            
            print("✅ Added \(armId)")
        }
        
        // Add legs
        for (i, legIndex) in analysis.legIndices.enumerated() {
            let legPath = paths[legIndex]
            let legId = "leg_\(i)"
            let footId = "foot_\(i)"
            
            let startPoint = legPath.points.first ?? CGPoint.zero
            let endPoint = legPath.points.last ?? CGPoint.zero
            
            let startDistToBody = distanceToLine(point: startPoint, lineStart: shoulderPosition, lineEnd: hipPosition)
            let endDistToBody = distanceToLine(point: endPoint, lineStart: shoulderPosition, lineEnd: hipPosition)
            
            let (legStart, legEnd) = startDistToBody < endDistToBody ? (startPoint, endPoint) : (endPoint, startPoint)
            
            joints[footId] = ReliableJoint(id: footId, position: legEnd)
            
            bones.append(ReliableBone(
                id: legId,
                start: "hip",
                end: footId,
                length: sqrt(pow(legEnd.x - legStart.x, 2) + pow(legEnd.y - legStart.y, 2)),
                pathIndex: legIndex
            ))
            
            print("✅ Added \(legId)")
        }
        
        let headPath = analysis.headIndex != nil ? (paths[analysis.headIndex!], analysis.headIndex!) : nil
        
        print("✅ Created adaptive skeleton: \(joints.count) joints, \(bones.count) bones")
        return (joints, bones, headPath)
    }
    
    // MARK: - Path Analysis
    
    struct PathAnalysis {
        let bodyIndex: Int?
        let headIndex: Int?
        let neckIndex: Int?
        let armIndices: [Int]
        let legIndices: [Int]
    }
    
    private static func analyzePaths(_ paths: [DrawingPath]) -> PathAnalysis {
        var bodyIndex: Int?
        var headIndex: Int?
        var neckIndex: Int?
        var armIndices: [Int] = []
        var legIndices: [Int] = []
        
        // Find body first (longest vertical line)
        var bestBodyScore: CGFloat = 0
        for (index, path) in paths.enumerated() {
            let bounds = path.boundingBox
            let verticalness = bounds.height / max(bounds.width, 1)
            let size = bounds.height
            
            if verticalness > 1.2 && size > 40 {
                let score = verticalness * size
                if score > bestBodyScore {
                    bestBodyScore = score
                    bodyIndex = index
                }
            }
        }
        
        guard let bodyIdx = bodyIndex else {
            return PathAnalysis(bodyIndex: nil, headIndex: nil, neckIndex: nil, armIndices: [], legIndices: [])
        }
        
        let bodyBounds = paths[bodyIdx].boundingBox
        
        // Analyze remaining paths
        for (index, path) in paths.enumerated() {
            guard index != bodyIdx else { continue }
            
            let bounds = path.boundingBox
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            let aspectRatio = bounds.width / bounds.height
            
            // Check for head (circular, above body)
            if aspectRatio > 0.6 && aspectRatio < 1.6 && path.points.count > 8 && center.y < bodyBounds.minY {
                headIndex = index
                print("  🎯 Found head at index \(index)")
                continue
            }
            
            // Check for neck (short vertical line near top of body)
            let verticalness = bounds.height / max(bounds.width, 1)
            if verticalness > 1.0 && bounds.height < bodyBounds.height * 0.3 &&
               abs(center.x - bodyBounds.midX) < 30 && center.y < bodyBounds.midY {
                neckIndex = index
                print("  🎯 Found neck at index \(index)")
                continue
            }
            
            // Check position relative to body
            let relativeY = center.y - bodyBounds.midY
            
            if relativeY < 0 {
                // Upper area - likely arms
                armIndices.append(index)
                print("  🎯 Found arm at index \(index)")
            } else {
                // Lower area - likely legs
                legIndices.append(index)
                print("  🎯 Found leg at index \(index)")
            }
        }
        
        return PathAnalysis(
            bodyIndex: bodyIdx,
            headIndex: headIndex,
            neckIndex: neckIndex,
            armIndices: armIndices,
            legIndices: legIndices
        )
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
    private static func animateJointsForWalking(
        _ originalJoints: [String: ReliableJoint],
        walkPhase: Double,
        forwardOffset: Double
    ) -> [String: ReliableJoint] {
        
        var joints = originalJoints
        
        // Walking motion parameters
        let bodyBob = sin(walkPhase * 2 * .pi) * 6
        let bodySway = sin(walkPhase * 4 * .pi) * 2
        
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
                y: hip.currentPosition.y - 60 + bodyBob * 0.8
            ))
            joints["shoulder"] = shoulder
        }

        // 3. Move neck if it exists - KEEP IT CONNECTED TO SHOULDER
            if var neckStart = joints["neck_start"],
               let shoulder = joints["shoulder"] {
                // Neck start should be near the shoulder
                neckStart.moveTo(CGPoint(
                    x: shoulder.currentPosition.x,
                    y: shoulder.currentPosition.y - 5  // Just above shoulder
                ))
                joints["neck_start"] = neckStart
                
                // Neck end maintains the original length
                if var neckEnd = joints["neck_end"] {
                    let neckLength = sqrt(pow(neckEnd.originalPosition.x - neckStart.originalPosition.x, 2) +
                                        pow(neckEnd.originalPosition.y - neckStart.originalPosition.y, 2))
                    neckEnd.moveTo(CGPoint(
                        x: neckStart.currentPosition.x,
                        y: neckStart.currentPosition.y - neckLength  // Maintain original neck length
                    ))
                    joints["neck_end"] = neckEnd
                    
                    print("🦴 Neck: start(\(Int(neckStart.currentPosition.x)), \(Int(neckStart.currentPosition.y))) → end(\(Int(neckEnd.currentPosition.x)), \(Int(neckEnd.currentPosition.y)))")
                }
            }
            
        // 4. Move head following neck or shoulder - IMPROVED
        if var headCenter = joints["head_center"] {
            // First try to follow neck end, then neck start, then shoulder
            let referenceJoint = joints["neck_end"] ?? joints["neck_start"] ?? joints["shoulder"]
            
            if let reference = referenceJoint {
                // Head follows the reference point with slight movement
                let headNod = sin(walkPhase * 2 * .pi) * 2
                let headSway = sin(walkPhase * 2 * .pi) * 1
                
                headCenter.moveTo(CGPoint(
                    x: reference.currentPosition.x + headSway,
                    y: reference.currentPosition.y - 20 + headNod  // 20 pixels above reference
                ))
                joints["head_center"] = headCenter
                
                print("🎭 Head following \(reference.id): head at (\(Int(headCenter.currentPosition.x)), \(Int(headCenter.currentPosition.y))), ref at (\(Int(reference.currentPosition.x)), \(Int(reference.currentPosition.y)))")
            } else {
                print("⚠️ No reference joint found for head movement")
            }
        } else {
            print("⚠️ head_center joint not found")
        }

            
            // 5. Move arms with swinging motion
            let leftArmSwing = sin(walkPhase * 2 * .pi + .pi) * 15
            let rightArmSwing = sin(walkPhase * 2 * .pi) * 15
            
            // Animate all hand joints
            for (jointId, joint) in joints {
                if jointId.hasPrefix("hand_") {
                    var animatedJoint = joint
                    let armSwing = jointId.contains("0") ? leftArmSwing : rightArmSwing
                    let isLeft = jointId.contains("0")
                    
                    if let shoulder = joints["shoulder"] {
                        animatedJoint.moveTo(CGPoint(
                            x: shoulder.currentPosition.x + (isLeft ? -30 : 30) + armSwing,
                            y: shoulder.currentPosition.y + 20 + armSwing * 0.2
                        ))
                        joints[jointId] = animatedJoint
                    }
                }
            }
            
            // 6. Move legs with walking motion
            let leftLegSwing = sin(walkPhase * 2 * .pi) * 25
            let rightLegSwing = sin(walkPhase * 2 * .pi + .pi) * 25
            
            // Animate all foot joints
            for (jointId, joint) in joints {
                if jointId.hasPrefix("foot_") {
                    var animatedJoint = joint
                    let legSwing = jointId.contains("0") ? leftLegSwing : rightLegSwing
                    let isLeft = jointId.contains("0")
                    
                    if let hip = joints["hip"] {
                        animatedJoint.moveTo(CGPoint(
                            x: hip.currentPosition.x + (isLeft ? -10 : 10) + legSwing,
                            y: hip.currentPosition.y + 50 + (legSwing > 0 ? -abs(legSwing) * 0.2 : 0)
                        ))
                        joints[jointId] = animatedJoint
                    }
                }
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
            guard bone.pathIndex < animatedPaths.count else {
                print("⚠️ Bone \(bone.id) has invalid path index \(bone.pathIndex)")
                continue
            }
            
            guard let startJoint = joints[bone.startJointId],
                  let endJoint = joints[bone.endJointId] else {
                print("⚠️ Missing joints for bone \(bone.id): \(bone.startJointId) or \(bone.endJointId)")
                continue
            }
            
            var newPath = DrawingPath()
            newPath.points = [startJoint.currentPosition, endJoint.currentPosition]
            newPath.rebuildPath()
            animatedPaths[bone.pathIndex] = newPath
            
            print("🦴 Updated \(bone.id): (\(Int(startJoint.currentPosition.x)), \(Int(startJoint.currentPosition.y))) → (\(Int(endJoint.currentPosition.x)), \(Int(endJoint.currentPosition.y)))")
        }
        
        // Update head path specially - IMPROVED HEAD MOVEMENT
        if let headInfo = headPath,
           let headJoint = joints["head_center"] {
            
            let originalHeadBounds = headInfo.path.boundingBox
            let originalCenter = CGPoint(x: originalHeadBounds.midX, y: originalHeadBounds.midY)
            
            // Calculate how much the head should move
            let deltaX = headJoint.currentPosition.x - originalCenter.x
            let deltaY = headJoint.currentPosition.y - originalCenter.y
            
            var newHeadPath = DrawingPath()
            for point in headInfo.path.points {
                newHeadPath.points.append(CGPoint(x: point.x + deltaX, y: point.y + deltaY))
            }
            newHeadPath.rebuildPath()
            animatedPaths[headInfo.index] = newHeadPath
            
            print("🎭 Head moved by (\(Int(deltaX)), \(Int(deltaY))) to center (\(Int(headJoint.currentPosition.x)), \(Int(headJoint.currentPosition.y)))")
        } else {
            print("⚠️ Head path or head joint not found")
            if headPath == nil {
                print("   - headPath is nil")
            }
            if joints["head_center"] == nil {
                print("   - head_center joint not found")
                print("   - Available joints: \(joints.keys.sorted().joined(separator: ", "))")
            }
        }
        
        return animatedPaths
    }
    
    // MARK: - Helper Methods
    
    private static func distanceToLine(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let length = sqrt(dx * dx + dy * dy)
        
        guard length > 0 else {
            return sqrt(pow(point.x - lineStart.x, 2) + pow(point.y - lineStart.y, 2))
        }
        
        let t = max(0, min(1, ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / (length * length)))
        let projection = CGPoint(x: lineStart.x + t * dx, y: lineStart.y + t * dy)
        
        return sqrt(pow(point.x - projection.x, 2) + pow(point.y - projection.y, 2))
    }
    
    private static func debugFrame(joints: [String: ReliableJoint], frameNumber: Int) {
        print("🦴 Frame \(frameNumber):")
        for (id, joint) in joints.sorted(by: { $0.key < $1.key }) {
            print("  \(id): (\(Int(joint.currentPosition.x)), \(Int(joint.currentPosition.y)))")
        }
    }
}
