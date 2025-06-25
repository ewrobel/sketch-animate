import Foundation
import CoreGraphics

// MARK: - Skeletal Animation System with Assumed Joints

struct Joint {
    let id: String
    var position: CGPoint
    var rotation: CGFloat = 0.0 // Current rotation angle
    var connectedBoneIds: [String] = []
    
    init(id: String, position: CGPoint) {
        self.id = id
        self.position = position
    }
}

struct Bone {
    let id: String
    let startJointId: String
    let endJointId: String
    let originalLength: CGFloat
    let originalAngle: CGFloat // Angle relative to start joint
    let pathIndex: Int // Which original path this bone represents
    
    init(id: String, startJointId: String, endJointId: String, length: CGFloat, angle: CGFloat, pathIndex: Int) {
        self.id = id
        self.startJointId = startJointId
        self.endJointId = endJointId
        self.originalLength = length
        self.originalAngle = angle
        self.pathIndex = pathIndex
    }
}

struct StickFigureSkeleton {
    var joints: [String: Joint] = [:]
    var bones: [Bone] = []
    var rootJointId: String = "hip"
    
    mutating func addJoint(_ joint: Joint) {
        joints[joint.id] = joint
    }
    
    mutating func addBone(_ bone: Bone) {
        bones.append(bone)
        joints[bone.startJointId]?.connectedBoneIds.append(bone.id)
        joints[bone.endJointId]?.connectedBoneIds.append(bone.id)
    }
    
    func getJoint(_ id: String) -> Joint? {
        return joints[id]
    }
    
    mutating func updateJointPosition(_ id: String, to position: CGPoint) {
        joints[id]?.position = position
    }
    
    mutating func updateJointRotation(_ id: String, rotation: CGFloat) {
        joints[id]?.rotation = rotation
    }
}

class SkeletalAnimator {
    
    // MARK: - Create Skeleton with Assumed Joint Structure
    
    static func createStickFigureSkeleton(from paths: [DrawingPath]) -> StickFigureSkeleton? {
        print("🦴 Creating stick figure skeleton with assumed joints")
        
        // Analyze the drawing to identify body parts
        let analysis = analyzeStickFigureStructure(paths)
        
        guard let bodyPath = analysis.bodyPath else {
            print("❌ No body path found")
            return nil
        }
        
        var skeleton = StickFigureSkeleton()
        
        // Create standard stick figure joint structure
        let bodyBounds = bodyPath.boundingBox
        let bodyCenter = CGPoint(x: bodyBounds.midX, y: bodyBounds.midY)
        let bodyTop = CGPoint(x: bodyBounds.midX, y: bodyBounds.minY)
        let bodyBottom = CGPoint(x: bodyBounds.midX, y: bodyBounds.maxY)
        
        // Define joint positions based on body proportions
        let hipY = bodyBottom.y - bodyBounds.height * 0.1
        let shoulderY = bodyTop.y + bodyBounds.height * 0.2
        let neckY = bodyTop.y
        
        // Create joints
        skeleton.addJoint(Joint(id: "head", position: CGPoint(x: bodyCenter.x, y: neckY - 20)))
        skeleton.addJoint(Joint(id: "neck", position: CGPoint(x: bodyCenter.x, y: neckY)))
        skeleton.addJoint(Joint(id: "shoulder_left", position: CGPoint(x: bodyCenter.x - 10, y: shoulderY)))
        skeleton.addJoint(Joint(id: "shoulder_right", position: CGPoint(x: bodyCenter.x + 10, y: shoulderY)))
        skeleton.addJoint(Joint(id: "hip", position: CGPoint(x: bodyCenter.x, y: hipY)))
        skeleton.addJoint(Joint(id: "hip_left", position: CGPoint(x: bodyCenter.x - 5, y: hipY)))
        skeleton.addJoint(Joint(id: "hip_right", position: CGPoint(x: bodyCenter.x + 5, y: hipY)))
        
        // Create bones from body path
        skeleton.addBone(Bone(
            id: "spine",
            startJointId: "hip",
            endJointId: "neck",
            length: bodyBounds.height * 0.8,
            angle: -.pi/2, // Pointing up
            pathIndex: analysis.bodyPathIndex
        ))
        
        // Create limb bones based on detected paths
        var boneIndex = 0
        
        for (index, limbPath) in analysis.limbPaths.enumerated() {
            let limbBounds = limbPath.boundingBox
            let limbCenter = CGPoint(x: limbBounds.midX, y: limbBounds.midY)
            let limbLength = max(limbBounds.width, limbBounds.height)
            
            // Determine which limb this is based on position relative to body
            let relativeX = limbCenter.x - bodyCenter.x
            let relativeY = limbCenter.y - bodyCenter.y
            
            var startJointId: String
            var endJointId: String
            var limbAngle: CGFloat
            
            if relativeY < -bodyBounds.height * 0.1 {
                // Upper area - arms
                if relativeX < 0 {
                    // Left arm
                    startJointId = "shoulder_left"
                    endJointId = "hand_left"
                    skeleton.addJoint(Joint(id: "hand_left", position: CGPoint(
                        x: limbBounds.minX,
                        y: limbCenter.y
                    )))
                } else {
                    // Right arm
                    startJointId = "shoulder_right"
                    endJointId = "hand_right"
                    skeleton.addJoint(Joint(id: "hand_right", position: CGPoint(
                        x: limbBounds.maxX,
                        y: limbCenter.y
                    )))
                }
                limbAngle = atan2(relativeY, abs(relativeX))
            } else {
                // Lower area - legs
                if relativeX < 0 {
                    // Left leg
                    startJointId = "hip_left"
                    endJointId = "foot_left"
                    skeleton.addJoint(Joint(id: "foot_left", position: CGPoint(
                        x: limbCenter.x,
                        y: limbBounds.maxY
                    )))
                } else {
                    // Right leg
                    startJointId = "hip_right"
                    endJointId = "foot_right"
                    skeleton.addJoint(Joint(id: "foot_right", position: CGPoint(
                        x: limbCenter.x,
                        y: limbBounds.maxY
                    )))
                }
                limbAngle = atan2(abs(relativeY), abs(relativeX))
            }
            
            skeleton.addBone(Bone(
                id: "limb_\(boneIndex)",
                startJointId: startJointId,
                endJointId: endJointId,
                length: limbLength,
                angle: limbAngle,
                pathIndex: analysis.limbPathIndices[index]
            ))
            
            boneIndex += 1
        }
        
        print("✅ Created skeleton with \(skeleton.joints.count) joints and \(skeleton.bones.count) bones")
        return skeleton
    }
    
    // MARK: - Structure Analysis
    
    struct StickFigureAnalysis {
        let bodyPath: DrawingPath?
        let bodyPathIndex: Int
        let limbPaths: [DrawingPath]
        let limbPathIndices: [Int]
    }
    
    private static func analyzeStickFigureStructure(_ paths: [DrawingPath]) -> StickFigureAnalysis {
        var bodyPath: DrawingPath?
        var bodyPathIndex = 0
        var maxVerticalLength: CGFloat = 0
        
        // Find the main vertical line (body)
        for (index, path) in paths.enumerated() {
            let bounds = path.boundingBox
            
            if bounds.height > bounds.width && bounds.height > maxVerticalLength {
                maxVerticalLength = bounds.height
                bodyPath = path
                bodyPathIndex = index
            }
        }
        
        // Collect remaining paths as limbs
        var limbPaths: [DrawingPath] = []
        var limbPathIndices: [Int] = []
        
        for (index, path) in paths.enumerated() {
            if index != bodyPathIndex {
                limbPaths.append(path)
                limbPathIndices.append(index)
            }
        }
        
        return StickFigureAnalysis(
            bodyPath: bodyPath,
            bodyPathIndex: bodyPathIndex,
            limbPaths: limbPaths,
            limbPathIndices: limbPathIndices
        )
    }
    
    // MARK: - Walking Animation with Joint Rotation
    
    static func generateWalkingFrames(skeleton: StickFigureSkeleton, originalPaths: [DrawingPath], totalFrames: Int) -> [AnimationFrame] {
        var frames: [AnimationFrame] = []
        
        for frameIndex in 0..<totalFrames {
            let progress = Double(frameIndex) / Double(totalFrames)
            let walkCycle = (progress * 2).truncatingRemainder(dividingBy: 1.0) // 2 complete walk cycles
            
            // Create animated skeleton for this frame
            let animatedSkeleton = animateSkeletonWithRotation(skeleton, walkPhase: walkCycle, forwardOffset: progress * 300)
            
            // Convert skeleton back to paths while preserving original path structure
            let animatedPaths = convertSkeletonToOriginalPaths(animatedSkeleton, originalPaths: originalPaths)
            frames.append(AnimationFrame(paths: animatedPaths, frameNumber: frameIndex))
        }
        
        return frames
    }
    
    private static func animateSkeletonWithRotation(_ skeleton: StickFigureSkeleton, walkPhase: Double, forwardOffset: Double) -> StickFigureSkeleton {
        var animatedSkeleton = skeleton
        
        // Move the entire figure forward
        let baseOffset = CGPoint(x: forwardOffset, y: 0)
        
        // Hip movement (root joint)
        let bodyBob = sin(walkPhase * 2 * .pi) * 8
        let hipSway = sin(walkPhase * 2 * .pi) * 3
        
        if let hipJoint = skeleton.getJoint("hip") {
            let newHipPosition = CGPoint(
                x: hipJoint.position.x + baseOffset.x + hipSway,
                y: hipJoint.position.y + baseOffset.y + bodyBob
            )
            animatedSkeleton.updateJointPosition("hip", to: newHipPosition)
        }
        
        // Update other joints with rotational animation
        animatedSkeleton = animateJointsWithRotation(animatedSkeleton, walkPhase: walkPhase, baseOffset: baseOffset)
        
        return animatedSkeleton
    }
    
    private static func animateJointsWithRotation(_ skeleton: StickFigureSkeleton, walkPhase: Double, baseOffset: CGPoint) -> StickFigureSkeleton {
        var result = skeleton
        
        // Define walking rotations for different joints
        let leftLegSwing = sin(walkPhase * 2 * .pi) * 0.6 // 35 degrees
        let rightLegSwing = sin(walkPhase * 2 * .pi + .pi) * 0.6
        let leftArmSwing = sin(walkPhase * 2 * .pi + .pi) * 0.4 // Arms opposite to legs
        let rightArmSwing = sin(walkPhase * 2 * .pi) * 0.4
        
        // Apply rotations and update joint positions
        let jointAnimations: [(String, CGFloat)] = [
            ("hip_left", leftLegSwing),
            ("hip_right", rightLegSwing),
            ("shoulder_left", leftArmSwing),
            ("shoulder_right", rightArmSwing)
        ]
        
        for (jointId, rotation) in jointAnimations {
            result.updateJointRotation(jointId, rotation: rotation)
            
            // Update connected bone endpoints based on rotation
            if let joint = result.getJoint(jointId) {
                let basePosition = CGPoint(
                    x: joint.position.x + baseOffset.x,
                    y: joint.position.y + baseOffset.y
                )
                result.updateJointPosition(jointId, to: basePosition)
                
                // Update connected joints (like hands and feet)
                for bone in result.bones {
                    if bone.startJointId == jointId {
                        let totalRotation = bone.originalAngle + rotation
                        let endPosition = CGPoint(
                            x: basePosition.x + cos(totalRotation) * bone.originalLength,
                            y: basePosition.y + sin(totalRotation) * bone.originalLength
                        )
                        result.updateJointPosition(bone.endJointId, to: endPosition)
                    }
                }
            }
        }
        
        return result
    }
    
    // MARK: - Convert Back to Original Path Structure
    
    private static func convertSkeletonToOriginalPaths(_ skeleton: StickFigureSkeleton, originalPaths: [DrawingPath]) -> [DrawingPath] {
        var animatedPaths = originalPaths // Start with original structure
        
        // Update each path based on corresponding bone
        for bone in skeleton.bones {
            guard bone.pathIndex < animatedPaths.count,
                  let startJoint = skeleton.getJoint(bone.startJointId),
                  let endJoint = skeleton.getJoint(bone.endJointId) else {
                continue
            }
            
            // Replace the path with a line from start joint to end joint
            var newPath = DrawingPath()
            newPath.points = [startJoint.position, endJoint.position]
            newPath.rebuildPath()
            animatedPaths[bone.pathIndex] = newPath
        }
        
        return animatedPaths
    }
    
    // MARK: - Legacy Interface
    
    static func createSkeleton(from paths: [DrawingPath]) -> StickFigureSkeleton? {
        return createStickFigureSkeleton(from: paths)
    }
    
    static func generateWalkingFrames(skeleton: StickFigureSkeleton, totalFrames: Int) -> [AnimationFrame] {
        // This method needs original paths for proper reconstruction
        // For now, create simple paths from skeleton
        let simplePaths = skeleton.bones.map { bone -> DrawingPath in
            guard let startJoint = skeleton.getJoint(bone.startJointId),
                  let endJoint = skeleton.getJoint(bone.endJointId) else {
                return DrawingPath()
            }
            
            var path = DrawingPath()
            path.points = [startJoint.position, endJoint.position]
            path.rebuildPath()
            return path
        }
        
        return generateWalkingFrames(skeleton: skeleton, originalPaths: simplePaths, totalFrames: totalFrames)
    }
}
