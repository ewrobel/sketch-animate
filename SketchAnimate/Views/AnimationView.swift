import SwiftUI

struct AnimationView: View {
    let animationFrames: [AnimationFrame]
    @State private var currentFrame = 0
    @State private var isPlaying = false
    @State private var animationTimer: Timer?
    @State private var progress: Double = 0
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Main animation canvas with enhanced styling
            animationCanvas
            
            // Floating controls overlay
            VStack {
                Spacer()
                
                HStack {
                    // Progress indicator
                    progressIndicator
                    
                    Spacer()
                    
                    // Frame counter
                    frameCounter
                }
                .padding(16)
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .padding()
            }
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    // MARK: - Animation Canvas
    
    private var animationCanvas: some View {
        Canvas { context, size in
            if currentFrame < animationFrames.count {
                let frame = animationFrames[currentFrame]
                
                // Draw each path in the current frame with enhanced effects
                for (index, animatedPath) in frame.paths.enumerated() {
                    // Add subtle shadow for depth
                    context.drawLayer(content: { layerContext in
                        layerContext.stroke(
                            animatedPath.path,
                            with: .color(.black.opacity(0.15)),
                            style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round)
                        )
                    })
                    
                    // Main stroke with dynamic colors
                    let hue = Double(index) * 0.15
                    let animationProgress = Double(currentFrame) / Double(max(animationFrames.count - 1, 1))
                    let saturation = 0.7 + sin(animationProgress * .pi * 4) * 0.2
                    let brightness = 0.4 + cos(animationProgress * .pi * 2) * 0.1
                    
                    let dynamicColor = Color(hue: hue, saturation: saturation, brightness: brightness)
                    
                    context.stroke(
                        animatedPath.path,
                        with: .color(dynamicColor),
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                    )
                    
                    // Add sparkle effect at path endpoints during animation
                    if let firstPoint = animatedPath.points.first,
                       let lastPoint = animatedPath.points.last,
                       currentFrame % 5 == 0 { // Sparkle every 5 frames
                        
                        // Sparkle at start
                        drawSparkle(context: context, at: firstPoint, size: 6)
                        
                        // Sparkle at end
                        drawSparkle(context: context, at: lastPoint, size: 6)
                    }
                }
                
                // Add motion trails for dynamic elements
                if currentFrame > 0 && currentFrame < animationFrames.count {
                    drawMotionTrails(context: context, size: size)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            // Animated background gradient
            AnimatedGradientBackground(progress: progress)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
    }
    
    // MARK: - UI Components
    
    private var progressIndicator: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "play.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text("Playing")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 8)
                        .animation(.linear(duration: 0.1), value: progress)
                }
            }
            .frame(height: 8)
        }
        .frame(width: 120)
    }
    
    private var frameCounter: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack {
                Image(systemName: "viewfinder")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Frame")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("\(currentFrame + 1) / \(animationFrames.count)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Animation Control
    
    private func startAnimation() {
        guard !animationFrames.isEmpty && !isPlaying else { return }
        
        print("🎬 Starting enhanced animation with \(animationFrames.count) frames")
        isPlaying = true
        currentFrame = 0
        progress = 0
        
        // 10 FPS playback with smoother progress updates
        let frameDuration = 0.1
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: frameDuration, repeats: true) { timer in
            currentFrame += 1
            progress = Double(currentFrame) / Double(animationFrames.count)
            
            if currentFrame >= animationFrames.count {
                stopAnimation()
                
                // Add completion animation
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    // Animation complete state
                }
                
                // Wait a moment then complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    onComplete()
                }
            }
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        isPlaying = false
        print("🎬 Enhanced animation stopped")
    }
    
    // MARK: - Visual Effects
    
    private func drawSparkle(context: GraphicsContext, at point: CGPoint, size: CGFloat) {
        let sparkleSize = size
        let sparkleRect = CGRect(
            x: point.x - sparkleSize/2,
            y: point.y - sparkleSize/2,
            width: sparkleSize,
            height: sparkleSize
        )
        
        // Draw sparkle as a small star
        context.fill(
            Path(ellipseIn: sparkleRect),
            with: .color(.yellow.opacity(0.8))
        )
        
        // Add smaller center dot
        let centerRect = CGRect(
            x: point.x - sparkleSize/4,
            y: point.y - sparkleSize/4,
            width: sparkleSize/2,
            height: sparkleSize/2
        )
        
        context.fill(
            Path(ellipseIn: centerRect),
            with: .color(.white)
        )
    }
    
    private func drawMotionTrails(context: GraphicsContext, size: CGSize) {
        guard currentFrame > 0 else { return }
        
        let previousFrame = animationFrames[currentFrame - 1]
        let currentFrameData = animationFrames[currentFrame]
        
        // Draw faint trails showing movement
        for (index, (prevPath, currPath)) in zip(previousFrame.paths, currentFrameData.paths).enumerated() {
            guard let prevStart = prevPath.points.first,
                  let currStart = currPath.points.first else { continue }
            
            // Draw trail line
            var trailPath = Path()
            trailPath.move(to: prevStart)
            trailPath.addLine(to: currStart)
            
            context.stroke(
                trailPath,
                with: .color(.blue.opacity(0.2)),
                style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [3, 3])
            )
        }
    }
}

// MARK: - Animated Background

struct AnimatedGradientBackground: View {
    let progress: Double
    
    var body: some View {
        LinearGradient(
            colors: [
                Color.white,
                Color.blue.opacity(0.05 + progress * 0.05),
                Color.purple.opacity(0.03 + progress * 0.03),
                Color.white
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .animation(.linear(duration: 0.3), value: progress)
    }
}

// MARK: - Preview

struct AnimationView_Previews: PreviewProvider {
    static var previews: some View {
        // Create sample animation frames for preview
        let samplePath1 = DrawingPath()
        let samplePath2 = DrawingPath()
        
        let sampleFrames = [
            AnimationFrame(paths: [samplePath1, samplePath2], frameNumber: 0),
            AnimationFrame(paths: [samplePath1, samplePath2], frameNumber: 1),
            AnimationFrame(paths: [samplePath1, samplePath2], frameNumber: 2)
        ]
        
        return VStack {
            Text("Enhanced Animation View")
                .font(.title2)
                .fontWeight(.bold)
                .padding()
            
            AnimationView(animationFrames: sampleFrames) {
                print("Animation completed")
            }
            .frame(height: 400)
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}
