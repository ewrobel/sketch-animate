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
        
        // Handle neck - if it exists as a separate path
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
                pathIndex: neckIndex
            ))
            
            print("✅ Added neck bone preserving original path at index \(neckIndex)")
        } else {
            // Create a virtual neck joint even if no neck path exists
            let neckPosition = CGPoint(x: shoulderPosition.x, y: shoulderPosition.y - 20)
            joints["neck_end"] = ReliableJoint(id: "neck_end", position: neckPosition)
            print("✅ Added virtual neck joint at (\(Int(neckPosition.x)), \(Int(neckPosition.y)))")
        }
        
        // Add head positioning
        if let headIndex = analysis.headIndex {
            let headPath = paths[headIndex]
            let headBounds = headPath.boundingBox
            joints["head_center"] = ReliableJoint(id: "head_center", position: CGPoint(x: headBounds.midX, y: headBounds.midY))
            print("✅ Added head center joint at (\(Int(headBounds.midX)), \(Int(headBounds.midY)))")
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
    
    
    // Add this as a static function in ReliableSkeletalAnimator class:
    static func debugAnalyzePaths(_ paths: [DrawingPath]) -> String {
        var result = "🔍 BODY PART ANALYSIS\n"
        result += "═══════════════════════\n\n"
        
        guard !paths.isEmpty else {
            return result + "❌ No paths to analyze"
        }
        
        result += "📊 Overview:\n"
        result += "- Total paths: \(paths.count)\n\n"
        
        // Analyze each path individually
        for (index, path) in paths.enumerated() {
            let bounds = path.boundingBox
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            let aspectRatio = bounds.width / bounds.height
            let verticalness = bounds.height / max(bounds.width, 1)
            
            result += "📍 PATH \(index):\n"
            result += "  Size: \(Int(bounds.width)) x \(Int(bounds.height))\n"
            result += "  Center: (\(Int(center.x)), \(Int(center.y)))\n"
            result += "  Aspect: \(String(format: "%.2f", aspectRatio))\n"
            result += "  Vertical: \(String(format: "%.2f", verticalness))\n"
            result += "  Points: \(path.points.count)\n"
            
            // Classify this path
            if aspectRatio > 0.6 && aspectRatio < 1.6 && path.points.count > 8 {
                result += "  🎯 LIKELY: HEAD (circular)\n"
            } else if verticalness > 1.2 && bounds.height > 40 {
                result += "  🎯 LIKELY: BODY (tall vertical)\n"
            } else if verticalness > 1.0 && bounds.height < 30 {
                result += "  🎯 LIKELY: NECK (short vertical)\n"
            } else {
                result += "  🎯 LIKELY: LIMB (arm or leg)\n"
            }
            result += "\n"
        }
        
        // Run the actual analysis
        let analysis = analyzePaths(paths)
        
        result += "🎯 FINAL CLASSIFICATION:\n"
        result += "═══════════════════════\n"
        
        if let bodyIndex = analysis.bodyIndex {
            result += "✅ BODY: Path \(bodyIndex)\n"
        } else {
            result += "❌ BODY: Not found\n"
        }
        
        if let headIndex = analysis.headIndex {
            result += "✅ HEAD: Path \(headIndex)\n"
        } else {
            result += "❌ HEAD: Not found\n"
        }
        
        if let neckIndex = analysis.neckIndex {
            result += "✅ NECK: Path \(neckIndex)\n"
        } else {
            result += "❌ NECK: Not found\n"
        }
        
        result += "✅ ARMS: \(analysis.armIndices.count) found"
        if !analysis.armIndices.isEmpty {
            result += " (paths: \(analysis.armIndices.map(String.init).joined(separator: ", ")))"
        }
        result += "\n"
        
        result += "✅ LEGS: \(analysis.legIndices.count) found"
        if !analysis.legIndices.isEmpty {
            result += " (paths: \(analysis.legIndices.map(String.init).joined(separator: ", ")))"
        }
        result += "\n\n"
        
        // Show what skeleton would be created
        if let skeletonData = createReliableSkeleton(from: paths) {
            result += "🦴 SKELETON CREATED:\n"
            result += "- Joints: \(skeletonData.joints.count)\n"
            result += "- Bones: \(skeletonData.bones.count)\n"
            result += "- Head path: \(skeletonData.headPath != nil ? "Yes" : "No")\n\n"
            
            result += "Joint positions:\n"
            for (id, joint) in skeletonData.joints.sorted(by: { $0.key < $1.key }) {
                result += "  \(id): (\(Int(joint.originalPosition.x)), \(Int(joint.originalPosition.y)))\n"
            }
            
            result += "\nBones:\n"
            for bone in skeletonData.bones {
                result += "  \(bone.id): \(bone.startJointId) → \(bone.endJointId) (path \(bone.pathIndex))\n"
            }
        } else {
            result += "❌ SKELETON: Could not create\n"
        }
        
        return result
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
                bones: bones, // Pass bones parameter
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
    
    // MARK: - Animation Logic - FIXED VERSION
    private static func animateJointsForWalking(
        _ originalJoints: [String: ReliableJoint],
        bones: [ReliableBone], // Added bones parameter
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
            print("🦴 Hip moved to: (\(Int(hip.currentPosition.x)), \(Int(hip.currentPosition.y))) - forward: \(Int(forwardOffset)), sway: \(Int(bodySway))")
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

        // 3. FIXED: Handle neck joints with proper connection preservation
        if var neckStart = joints["neck_start"],
           let shoulder = joints["shoulder"] {
            // Neck start should move with the shoulder to stay connected
            neckStart.moveTo(CGPoint(
                x: shoulder.currentPosition.x,
                y: shoulder.currentPosition.y - 5  // Just above shoulder
            ))
            joints["neck_start"] = neckStart
            
            // Move neck end maintaining the EXACT original relationship to neck_start
            if var neckEnd = joints["neck_end"] {
                // Calculate the original vector from neck_start to neck_end
                let originalNeckVector = CGPoint(
                    x: neckEnd.originalPosition.x - neckStart.originalPosition.x,
                    y: neckEnd.originalPosition.y - neckStart.originalPosition.y
                )
                
                // Apply this exact vector from the NEW neck_start position
                neckEnd.moveTo(CGPoint(
                    x: neckStart.currentPosition.x + originalNeckVector.x,
                    y: neckStart.currentPosition.y + originalNeckVector.y
                ))
                joints["neck_end"] = neckEnd
                
                print("🦴 Neck connected: start(\(Int(neckStart.currentPosition.x)), \(Int(neckStart.currentPosition.y))) → end(\(Int(neckEnd.currentPosition.x)), \(Int(neckEnd.currentPosition.y))), vector(\(Int(originalNeckVector.x)), \(Int(originalNeckVector.y)))")
            }
        } else if var neckEnd = joints["neck_end"],
                  let shoulder = joints["shoulder"] {
            // If no neck_start but we have neck_end, position it relative to shoulder maintaining original offset
            let originalOffset = CGPoint(
                x: neckEnd.originalPosition.x - shoulder.originalPosition.x,
                y: neckEnd.originalPosition.y - shoulder.originalPosition.y
            )
            
            neckEnd.moveTo(CGPoint(
                x: shoulder.currentPosition.x + originalOffset.x,
                y: shoulder.currentPosition.y + originalOffset.y
            ))
            joints["neck_end"] = neckEnd
            
            print("🦴 Virtual neck: positioned at (\(Int(neckEnd.currentPosition.x)), \(Int(neckEnd.currentPosition.y))) relative to shoulder")
        }
            
        // 4. SUPER DETAILED HEAD CONNECTION - Debug every step
        if var headCenter = joints["head_center"] {
            if let neckEnd = joints["neck_end"] {
                // HEAD CONNECTED TO NECK: Maintain exact original offset from neck_end
                let originalHeadPos = headCenter.originalPosition
                let originalNeckEndPos = neckEnd.originalPosition
                let originalOffset = CGPoint(
                    x: originalHeadPos.x - originalNeckEndPos.x,
                    y: originalHeadPos.y - originalNeckEndPos.y
                )
                
                // Current neck position
                let currentNeckEndPos = neckEnd.currentPosition
                
                // Add small head animation
                let headNod = sin(walkPhase * 2 * .pi) * 2
                let headSway = sin(walkPhase * 2 * .pi) * 1
                
                // Calculate new head position: current neck + original offset + animation
                let newHeadX = currentNeckEndPos.x + originalOffset.x + headSway
                let newHeadY = currentNeckEndPos.y + originalOffset.y + headNod
                
                headCenter.moveTo(CGPoint(x: newHeadX, y: newHeadY))
                joints["head_center"] = headCenter
                
                print("🎭 DETAILED Head-Neck Connection:")
                print("   Original head: (\(Int(originalHeadPos.x)), \(Int(originalHeadPos.y)))")
                print("   Original neck end: (\(Int(originalNeckEndPos.x)), \(Int(originalNeckEndPos.y)))")
                print("   Original offset: (\(Int(originalOffset.x)), \(Int(originalOffset.y)))")
                print("   Current neck end: (\(Int(currentNeckEndPos.x)), \(Int(currentNeckEndPos.y)))")
                print("   New head pos: (\(Int(newHeadX)), \(Int(newHeadY)))")
                print("   Animation: nod=\(Int(headNod)), sway=\(Int(headSway))")
                
                // Verify the connection distance
                let connectionDistance = sqrt(pow(newHeadX - currentNeckEndPos.x, 2) + pow(newHeadY - currentNeckEndPos.y, 2))
                let originalDistance = sqrt(pow(originalOffset.x, 2) + pow(originalOffset.y, 2))
                print("   Connection distance: \(Int(connectionDistance)) (original: \(Int(originalDistance)))")
                
            } else if let shoulder = joints["shoulder"] {
                // FALLBACK: Head follows shoulder if no neck_end
                let originalHeadPos = headCenter.originalPosition
                let originalShoulderPos = shoulder.originalPosition
                let originalOffset = CGPoint(
                    x: originalHeadPos.x - originalShoulderPos.x,
                    y: originalHeadPos.y - originalShoulderPos.y
                )
                
                let currentShoulderPos = shoulder.currentPosition
                let headNod = sin(walkPhase * 2 * .pi) * 2
                let headSway = sin(walkPhase * 2 * .pi) * 1
                
                let newHeadX = currentShoulderPos.x + originalOffset.x + headSway
                let newHeadY = currentShoulderPos.y + originalOffset.y + headNod
                
                headCenter.moveTo(CGPoint(x: newHeadX, y: newHeadY))
                joints["head_center"] = headCenter
                
                print("🎭 Head following shoulder (no neck): shoulder(\(Int(currentShoulderPos.x)), \(Int(currentShoulderPos.y))) → head(\(Int(newHeadX)), \(Int(newHeadY))), offset(\(Int(originalOffset.x)), \(Int(originalOffset.y)))")
                
            } else {
                print("⚠️ No neck_end or shoulder joint found for head movement reference")
                print("   Available joints: \(joints.keys.sorted().joined(separator: ", "))")
            }
        } else {
            print("⚠️ No head_center joint found!")
            print("   Available joints: \(joints.keys.sorted().joined(separator: ", "))")
        }

            
        // 5. Move arms with swinging motion
        let leftArmSwing = sin(walkPhase * 2 * .pi + .pi) * 15
        let rightArmSwing = sin(walkPhase * 2 * .pi) * 15
        
        // Animate all hand joints
        for (jointId, joint) in joints {
            if jointId.hasPrefix("hand_") {
                var animatedJoint = joint
                let armSwing = jointId.contains("0") ? leftArmSwing : rightArmSwing
                
                if let shoulder = joints["shoulder"] {
                    // Calculate original offset from shoulder to hand
                    let originalOffset = CGPoint(
                        x: joint.originalPosition.x - shoulder.originalPosition.x,
                        y: joint.originalPosition.y - shoulder.originalPosition.y
                    )
                    
                    // Apply offset plus arm swing
                    animatedJoint.moveTo(CGPoint(
                        x: shoulder.currentPosition.x + originalOffset.x + armSwing,
                        y: shoulder.currentPosition.y + originalOffset.y + armSwing * 0.2
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
                
                if let hip = joints["hip"] {
                    // Calculate original offset from hip to foot
                    let originalOffset = CGPoint(
                        x: joint.originalPosition.x - hip.originalPosition.x,
                        y: joint.originalPosition.y - hip.originalPosition.y
                    )
                    
                    // Apply offset plus leg swing and lift
                    let legLift = legSwing > 0 ? -abs(legSwing) * 0.2 : 0
                    
                    animatedJoint.moveTo(CGPoint(
                        x: hip.currentPosition.x + originalOffset.x + legSwing,
                        y: hip.currentPosition.y + originalOffset.y + legLift
                    ))
                    joints[jointId] = animatedJoint
                }
            }
        }
        
        // FINAL STEP: Validate all bone connections to ensure no disconnections
        validateBoneConnections(joints: joints, bones: bones)
        
        return joints
    }
    
    // MARK: - Connection Validation
    
    private static func validateBoneConnections(joints: [String: ReliableJoint], bones: [ReliableBone]) {
        for bone in bones {
            guard let startJoint = joints[bone.startJointId],
                  let endJoint = joints[bone.endJointId] else {
                print("⚠️ Missing joints for bone \(bone.id)")
                continue
            }
            
            let currentLength = sqrt(
                pow(endJoint.currentPosition.x - startJoint.currentPosition.x, 2) +
                pow(endJoint.currentPosition.y - startJoint.currentPosition.y, 2)
            )
            
            let originalLength = bone.length
            let lengthDifference = abs(currentLength - originalLength)
            
            // Warn if bone length has changed significantly (more than 10 pixels)
            if lengthDifference > 10 {
                print("⚠️ Bone \(bone.id) length changed: \(Int(originalLength)) → \(Int(currentLength)) (diff: \(Int(lengthDifference)))")
            }
        }
    }
    
    // MARK: - Convert to Paths - IMPROVED VERSION
    
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
        
        // DETAILED HEAD PATH TRANSFORMATION - Debug every step
        if let headInfo = headPath,
           let headJoint = joints["head_center"] {
            
            // Calculate exactly how much the head joint moved
            let originalHeadCenter = headJoint.originalPosition
            let currentHeadCenter = headJoint.currentPosition
            
            let deltaX = currentHeadCenter.x - originalHeadCenter.x
            let deltaY = currentHeadCenter.y - originalHeadCenter.y
            
            print("🎭 HEAD PATH TRANSFORMATION:")
            print("   Head joint original: (\(Int(originalHeadCenter.x)), \(Int(originalHeadCenter.y)))")
            print("   Head joint current: (\(Int(currentHeadCenter.x)), \(Int(currentHeadCenter.y)))")
            print("   Movement delta: (\(Int(deltaX)), \(Int(deltaY)))")
            print("   Head path has \(headInfo.path.points.count) points")
            
            // Apply this exact movement to every point in the head path
            var newHeadPath = DrawingPath()
            for (index, point) in headInfo.path.points.enumerated() {
                let newPoint = CGPoint(x: point.x + deltaX, y: point.y + deltaY)
                newHeadPath.points.append(newPoint)
                
                // Debug first and last points
                if index == 0 {
                    print("   First point: (\(Int(point.x)), \(Int(point.y))) → (\(Int(newPoint.x)), \(Int(newPoint.y)))")
                } else if index == headInfo.path.points.count - 1 {
                    print("   Last point: (\(Int(point.x)), \(Int(point.y))) → (\(Int(newPoint.x)), \(Int(newPoint.y)))")
                }
            }
            newHeadPath.rebuildPath()
            animatedPaths[headInfo.index] = newHeadPath
            
            print("   ✅ Head path updated with \(newHeadPath.points.count) points")
            
        } else {
            if headPath == nil {
                print("⚠️ No head path to animate - headPath is nil")
            }
            if joints["head_center"] == nil {
                print("⚠️ No head_center joint found")
                print("   Available joints: \(joints.keys.sorted().joined(separator: ", "))")
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
