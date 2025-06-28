import Foundation
import CoreGraphics

// MARK: - Connected Skeletal Animation System
// This ensures all body parts stay connected during animation

struct ConnectedJoint {
    let id: String
    var position: CGPoint
    let originalPosition: CGPoint
    var connectedBones: [String] = []
    
    init(id: String, position: CGPoint) {
        self.id = id
        self.position = position
        self.originalPosition = position
    }
    
    mutating func updatePosition(_ newPosition: CGPoint) {
        self.position = newPosition
    }
    
    mutating func addBone(_ boneId: String) {
        if !connectedBones.contains(boneId) {
            connectedBones.append(boneId)
        }
    }
}

struct ConnectedBone {
    let id: String
    let startJointId: String
    let endJointId: String
    let originalLength: CGFloat
    let pathIndex: Int
    
    init(id: String, startJoint: String, endJoint: String, length: CGFloat, pathIndex: Int) {
        self.id = id
        self.startJointId = startJoint
        self.endJointId = endJoint
        self.originalLength = length
        self.pathIndex = pathIndex
    }
    
    func getEndPosition(startPosition: CGPoint, targetEndPosition: CGPoint) -> CGPoint {
        // Maintain bone length while moving toward target
        let dx = targetEndPosition.x - startPosition.x
        let dy = targetEndPosition.y - startPosition.y
        let currentLength = sqrt(dx * dx + dy * dy)
        
        if currentLength < 1 {
            return CGPoint(x: startPosition.x, y: startPosition.y + originalLength)
        }
        
        let scale = originalLength / currentLength
        return CGPoint(
            x: startPosition.x + dx * scale,
            y: startPosition.y + dy * scale
        )
    }
}

struct ConnectedSkeleton {
    var joints: [String: ConnectedJoint] = [:]
    var bones: [String: ConnectedBone] = [:]
    let rootJointId: String
    
    init(rootJointId: String = "hip") {
        self.rootJointId = rootJointId
    }
    
    mutating func addJoint(_ joint: ConnectedJoint) {
        joints[joint.id] = joint
    }
    
    mutating func addBone(_ bone: ConnectedBone) {
        bones[bone.id] = bone
        joints[bone.startJointId]?.addBone(bone.id)
        joints[bone.endJointId]?.addBone(bone.id)
    }
    
    mutating func moveJoint(_ jointId: String, to position: CGPoint) {
        joints[jointId]?.updatePosition(position)
        
        // Update all connected bones to maintain connections
        updateConnectedBones(from: jointId)
    }
    
    private mutating func updateConnectedBones(from jointId: String) {
        guard let joint = joints[jointId] else { return }
        
        for boneId in joint.connectedBones {
            guard let bone = bones[boneId] else { continue }
            
            if bone.startJointId == jointId {
                // This joint is the start of the bone - update the end joint
                updateEndJoint(bone: bone)
            } else if bone.endJointId == jointId {
                // This joint is the end of the bone - update the start joint
                updateStartJoint(bone: bone)
            }
        }
    }
    
    private mutating func updateEndJoint(bone: ConnectedBone) {
        guard let startJoint = joints[bone.startJointId],
              let endJoint = joints[bone.endJointId] else { return }
        
        let correctedEndPosition = bone.getEndPosition(
            startPosition: startJoint.position,
            targetEndPosition: endJoint.position
        )
        
        joints[bone.endJointId]?.updatePosition(correctedEndPosition)
    }
    
    private mutating func updateStartJoint(bone: ConnectedBone) {
        guard let startJoint = joints[bone.startJointId],
              let endJoint = joints[bone.endJointId] else { return }
        
        // Calculate where start should be to maintain bone length
        let dx = endJoint.position.x - startJoint.position.x
        let dy = endJoint.position.y - startJoint.position.y
        let currentLength = sqrt(dx * dx + dy * dy)
        
        if currentLength > 1 {
            let scale = bone.originalLength / currentLength
            let correctedStartPosition = CGPoint(
                x: endJoint.position.x - dx * scale,
                y: endJoint.position.y - dy * scale
            )
            joints[bone.startJointId]?.updatePosition(correctedStartPosition)
        }
    }
    
    func getJoint(_ id: String) -> ConnectedJoint? {
        return joints[id]
    }
    
    func getBone(_ id: String) -> ConnectedBone? {
        return bones[id]
    }
}

class ConnectedSkeletalAnimator {
    
    // MARK: - Create Connected Skeleton
    
    static func createConnectedSkeleton(from paths: [DrawingPath]) -> ConnectedSkeleton? {
        print("🦴 Creating connected skeleton from \(paths.count) paths")
        
        guard !paths.isEmpty else { return nil }
        
        // Find main body
        guard let bodyInfo = findMainBody(paths) else {
            print("❌ No main body found")
            return nil
        }
        
        let bodyPath = bodyInfo.path
        let bodyIndex = bodyInfo.index
        let bodyBounds = bodyPath.boundingBox
        
        print("✅ Found body: \(Int(bodyBounds.height))px tall")
        
        var skeleton = ConnectedSkeleton(rootJointId: "hip")
        
        // Create joints with proper spacing
        let bodyTop = bodyBounds.minY
        let bodyBottom = bodyBounds.maxY
        let bodyCenter = bodyBounds.midX
        let bodyHeight = bodyBounds.height
        
        // Joint positions based on human proportions
        let hipY = bodyBottom - bodyHeight * 0.1
        let shoulderY = bodyTop + bodyHeight * 0.15
        let neckY = bodyTop + bodyHeight * 0.05
        let headY = bodyTop - 15
        
        // Create all joints
        skeleton.addJoint(ConnectedJoint(id: "hip", position: CGPoint(x: bodyCenter, y: hipY)))
        skeleton.addJoint(ConnectedJoint(id: "shoulder", position: CGPoint(x: bodyCenter, y: shoulderY)))
        skeleton.addJoint(ConnectedJoint(id: "neck", position: CGPoint(x: bodyCenter, y: neckY)))
        skeleton.addJoint(ConnectedJoint(id: "head_center", position: CGPoint(x: bodyCenter, y: headY)))
        
        // Offset joints for limbs
        skeleton.addJoint(ConnectedJoint(id: "shoulder_left", position: CGPoint(x: bodyCenter - 15, y: shoulderY)))
        skeleton.addJoint(ConnectedJoint(id: "shoulder_right", position: CGPoint(x: bodyCenter + 15, y: shoulderY)))
        skeleton.addJoint(ConnectedJoint(id: "hip_left", position: CGPoint(x: bodyCenter - 8, y: hipY)))
        skeleton.addJoint(ConnectedJoint(id: "hip_right", position: CGPoint(x: bodyCenter + 8, y: hipY)))
        
        // Create main body bone
        skeleton.addBone(ConnectedBone(
            id: "torso",
            startJoint: "hip",
            endJoint: "shoulder",
            length: bodyHeight * 0.75,
            pathIndex: bodyIndex
        ))
        
        // Map limbs to skeleton
        var processedPaths: Set<Int> = [bodyIndex]
        
        for (pathIndex, path) in paths.enumerated() {
            guard !processedPaths.contains(pathIndex) else { continue }
            
            let limbInfo = classifyAndCreateLimb(path, pathIndex: pathIndex, bodyBounds: bodyBounds)
            
            if let limb = limbInfo {
                skeleton.addJoint(ConnectedJoint(id: limb.endJointId, position: limb.endPosition))
                skeleton.addBone(ConnectedBone(
                    id: limb.boneId,
                    startJoint: limb.startJointId,
                    endJoint: limb.endJointId,
                    length: limb.length,
                    pathIndex: pathIndex
                ))
                processedPaths.insert(pathIndex)
                
                print("✅ Added \(limb.boneId): \(limb.startJointId) → \(limb.endJointId)")
            }
        }
        
        print("✅ Created connected skeleton: \(skeleton.joints.count) joints, \(skeleton.bones.count) bones")
        return skeleton
    }
    
    // MARK: - Generate Walking Animation with Connections
    
    static func generateConnectedWalkingAnimation(
        skeleton: ConnectedSkeleton,
        originalPaths: [DrawingPath],
        totalFrames: Int
    ) -> [AnimationFrame] {
        
        print("🚶 Generating connected walking animation")
        
        var frames: [AnimationFrame] = []
        
        for frameIndex in 0..<totalFrames {
            let progress = Double(frameIndex) / Double(totalFrames)
            let walkPhase = (progress * 2).truncatingRemainder(dividingBy: 1.0)
            
            // Animate skeleton maintaining all connections
            let animatedSkeleton = animateConnectedSkeleton(
                skeleton,
                walkPhase: walkPhase,
                forwardOffset: progress * 250
            )
            
            // Convert to paths ensuring connections
            let animatedPaths = convertConnectedSkeletonToPaths(animatedSkeleton, originalPaths: originalPaths)
            
            frames.append(AnimationFrame(paths: animatedPaths, frameNumber: frameIndex))
            
            // Debug first few frames
            if frameIndex < 3 {
                debugConnections(animatedSkeleton, frameNumber: frameIndex)
            }
        }
        
        return frames
    }
    
    // MARK: - Connected Animation Logic
    
    private static func animateConnectedSkeleton(
        _ skeleton: ConnectedSkeleton,
        walkPhase: Double,
        forwardOffset: Double
    ) -> ConnectedSkeleton {
        
        var animatedSkeleton = skeleton
        
        // Root movement - this drives everything else
        let bodyBob = sin(walkPhase * 2 * .pi) * 6
        let bodySway = sin(walkPhase * 4 * .pi) * 2
        
        // Move the root (hip) - everything else follows
        if let hip = skeleton.getJoint("hip") {
            let newHipPosition = CGPoint(
                x: hip.originalPosition.x + forwardOffset + bodySway,
                y: hip.originalPosition.y + bodyBob
            )
            animatedSkeleton.moveJoint("hip", to: newHipPosition)
        }
        
        // Move shoulder maintaining connection to hip
        if let shoulder = skeleton.getJoint("shoulder"),
           let hip = animatedSkeleton.getJoint("hip") {
            let torsoLength = skeleton.getBone("torso")?.originalLength ?? -60
            let shoulderOffset = CGPoint(x: 0, y: torsoLength)
            let newShoulderPosition = CGPoint(
                x: hip.position.x + shoulderOffset.x + bodySway * 0.5,
                y: hip.position.y + shoulderOffset.y + bodyBob * 0.8
            )
            animatedSkeleton.moveJoint("shoulder", to: newShoulderPosition)
        }
        
        // Animate limbs with walking motion
        let leftLegSwing = sin(walkPhase * 2 * .pi) * 25
        let rightLegSwing = sin(walkPhase * 2 * .pi + .pi) * 25
        let leftArmSwing = sin(walkPhase * 2 * .pi + .pi) * 15  // Arms opposite legs
        let rightArmSwing = sin(walkPhase * 2 * .pi) * 15
        
        // Move limb endpoints - the skeleton will maintain connections
        animateLimbEndpoint(
            &animatedSkeleton,
            limbJoint: "hand_left",
            swing: leftArmSwing,
            lift: leftArmSwing * 0.2,
            forwardOffset: forwardOffset
        )
        
        animateLimbEndpoint(
            &animatedSkeleton,
            limbJoint: "hand_right",
            swing: rightArmSwing,
            lift: rightArmSwing * 0.2,
            forwardOffset: forwardOffset
        )
        
        animateLimbEndpoint(
            &animatedSkeleton,
            limbJoint: "foot_left",
            swing: leftLegSwing,
            lift: leftLegSwing > 0 ? -abs(leftLegSwing) * 0.3 : 0,
            forwardOffset: forwardOffset
        )
        
        animateLimbEndpoint(
            &animatedSkeleton,
            limbJoint: "foot_right",
            swing: rightLegSwing,
            lift: rightLegSwing > 0 ? -abs(rightLegSwing) * 0.3 : 0,
            forwardOffset: forwardOffset
        )
        
        return animatedSkeleton
    }
    
    private static func animateLimbEndpoint(
        _ skeleton: inout ConnectedSkeleton,
        limbJoint: String,
        swing: Double,
        lift: Double,
        forwardOffset: Double
    ) {
        guard let joint = skeleton.getJoint(limbJoint) else { return }
        
        let newPosition = CGPoint(
            x: joint.originalPosition.x + forwardOffset + swing,
            y: joint.originalPosition.y + lift
        )
        
        skeleton.moveJoint(limbJoint, to: newPosition)
    }
    
    // MARK: - Convert to Paths with Guaranteed Connections
    
    private static func convertConnectedSkeletonToPaths(_ skeleton: ConnectedSkeleton, originalPaths: [DrawingPath]) -> [DrawingPath] {
        var animatedPaths = originalPaths
        
        // Convert each bone back to a path, ensuring connections
        for (_, bone) in skeleton.bones {
            guard bone.pathIndex < animatedPaths.count,
                  let startJoint = skeleton.getJoint(bone.startJointId),
                  let endJoint = skeleton.getJoint(bone.endJointId) else {
                continue
            }
            
            // Create path that definitely connects start to end
            var newPath = DrawingPath()
            newPath.points = [startJoint.position, endJoint.position]
            newPath.rebuildPath()
            
            animatedPaths[bone.pathIndex] = newPath
        }
        
        // Handle head specially if it exists
        if let headPath = findHeadPath(originalPaths),
           let headCenter = skeleton.getJoint("head_center") {
            let headIndex = headPath.index
            var newHeadPath = DrawingPath()
            
            // Move the entire head shape
            let originalHeadBounds = headPath.path.boundingBox
            let deltaX = headCenter.position.x - originalHeadBounds.midX
            let deltaY = headCenter.position.y - originalHeadBounds.midY
            
            for point in headPath.path.points {
                let newPoint = CGPoint(x: point.x + deltaX, y: point.y + deltaY)
                newHeadPath.points.append(newPoint)
            }
            
            newHeadPath.rebuildPath()
            animatedPaths[headIndex] = newHeadPath
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
            let size = bounds.height
            
            if verticalness > 1.2 && size > 40 {
                let score = verticalness * size
                if score > bestScore {
                    bestScore = score
                    bestIndex = index
                }
            }
        }
        
        return bestScore > 0 ? (paths[bestIndex], bestIndex) : nil
    }
    
    private static func findHeadPath(_ paths: [DrawingPath]) -> (path: DrawingPath, index: Int)? {
        // Look for circular-ish paths (head)
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
        let boneId: String
        let startJointId: String
        let endJointId: String
        let endPosition: CGPoint
        let length: CGFloat
    }
    
    private static func classifyAndCreateLimb(_ path: DrawingPath, pathIndex: Int, bodyBounds: CGRect) -> LimbInfo? {
        let bounds = path.boundingBox
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let length = max(bounds.width, bounds.height)
        
        let relativeX = center.x - bodyBounds.midX
        let relativeY = center.y - bodyBounds.midY
        
        // Classify based on position relative to body
        if relativeY < -bodyBounds.height * 0.1 {
            // Upper area - arms
            if relativeX < 0 {
                return LimbInfo(
                    boneId: "left_arm",
                    startJointId: "shoulder_left",
                    endJointId: "hand_left",
                    endPosition: CGPoint(x: bounds.minX, y: bounds.midY),
                    length: length
                )
            } else {
                return LimbInfo(
                    boneId: "right_arm",
                    startJointId: "shoulder_right",
                    endJointId: "hand_right",
                    endPosition: CGPoint(x: bounds.maxX, y: bounds.midY),
                    length: length
                )
            }
        } else if relativeY > bodyBounds.height * 0.1 {
            // Lower area - legs
            if relativeX < 0 {
                return LimbInfo(
                    boneId: "left_leg",
                    startJointId: "hip_left",
                    endJointId: "foot_left",
                    endPosition: CGPoint(x: bounds.midX, y: bounds.maxY),
                    length: length
                )
            } else {
                return LimbInfo(
                    boneId: "right_leg",
                    startJointId: "hip_right",
                    endJointId: "foot_right",
                    endPosition: CGPoint(x: bounds.midX, y: bounds.maxY),
                    length: length
                )
            }
        }
        
        return nil
    }
    
    private static func debugConnections(_ skeleton: ConnectedSkeleton, frameNumber: Int) {
        print("🔗 Frame \(frameNumber) connections:")
        for (boneId, bone) in skeleton.bones {
            if let start = skeleton.getJoint(bone.startJointId),
               let end = skeleton.getJoint(bone.endJointId) {
                let distance = sqrt(pow(end.position.x - start.position.x, 2) + pow(end.position.y - start.position.y, 2))
                print("  \(boneId): \(String(format: "%.1f", distance))px (target: \(String(format: "%.1f", bone.originalLength)))")
            }
        }
    }
}
