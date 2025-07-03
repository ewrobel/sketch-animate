import SwiftUI

struct ContentView: View {
    @State private var paths: [DrawingPath] = []
    @State private var currentPath = DrawingPath()
    @State private var showingTests = false
    @State private var isProcessing = false
    @State private var detectedObject: ObjectType?
    @State private var showBodyPartAnalysis = false
    @State private var bodyPartAnalysis: String = ""
    @State private var isAnimating = false
    @State private var animationFrames: [AnimationFrame] = []
    @StateObject private var aiService = AIAnalysisService()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Beautiful gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.97, blue: 1.0),
                        Color(red: 0.92, green: 0.95, blue: 0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Modern Header
                    headerView
                    
                    if showingTests {
                        // Debug/Test Results - kept for development
                        DebugView(paths: paths)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    } else {
                        // Main content area
                        mainContentView(geometry: geometry)
                        
                        // Bottom section
                        bottomSectionView
                    }
                }
            }
        }
        .overlay(
            // Body part analysis overlay
            bodyPartAnalysisOverlay
        )
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showingTests)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: detectedObject)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showBodyPartAnalysis)
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack(spacing: 0) {
            // App title with icon
            HStack(spacing: 12) {
                Image(systemName: "paintbrush.pointed.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("SketchAnimate")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Bring your drawings to life")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Header buttons
            HStack(spacing: 12) {
                // Clear button
                Button(action: clearDrawing) {
                    Label("Clear", systemImage: "trash")
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Color.red.opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .opacity(paths.isEmpty ? 0.6 : 1.0)
                .disabled(paths.isEmpty)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            .ultraThinMaterial,
            in: Rectangle()
        )
    }
    
    // MARK: - Main Content View
    
    private func mainContentView(geometry: GeometryProxy) -> some View {
        ZStack {
            if isAnimating {
                // Animation view with beautiful styling
                animationDisplayView
            } else {
                // Drawing canvas with enhanced design
                drawingCanvasView(geometry: geometry)
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    private var animationDisplayView: some View {
        VStack(spacing: 20) {
            // Animation header
            HStack {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Animation Playing")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Stop") {
                    isAnimating = false
                    clearDrawing()
                }
                .font(.subheadline)
                .foregroundColor(.red)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Color.red.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 12)
                )
            }
            .padding(.horizontal, 24)
            
            // Animation view
            AnimationView(animationFrames: animationFrames) {
                isAnimating = false
                clearDrawing()
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            )
            .padding(.horizontal, 24)
            
            Text("Tap stop or wait for animation to complete")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
        }
    }
    
    private func drawingCanvasView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 20) {
            // Canvas header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Drawing Canvas")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    if !paths.isEmpty {
                        Text("\(paths.count) stroke\(paths.count == 1 ? "" : "s") drawn")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Draw with your finger to get started")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if !paths.isEmpty {
                    Button("Show Analysis") {
                        analyzeAndShowBodyParts()
                        showBodyPartAnalysis.toggle()
                    }
                    .font(.caption)
                    .foregroundColor(.purple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Color.purple.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                }
            }
            .padding(.horizontal, 24)
            
            // Drawing canvas
            ZStack {
                // Canvas background with subtle pattern
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 8)
                
                // Subtle grid pattern
                if paths.isEmpty && currentPath.points.isEmpty {
                    canvasPlaceholder
                }
                
                // Drawing canvas
                DrawingCanvas(paths: $paths, currentPath: $currentPath)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                
                // Processing overlay
                if isProcessing {
                    processingOverlay
                }
            }
            .padding(.horizontal, 24)
            .frame(height: geometry.size.height * 0.6)
        }
    }
    
    private var canvasPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.draw")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 4) {
                Text("Start Drawing!")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Draw a stick figure, ball, or anything creative!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var processingOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                
                VStack(spacing: 8) {
                    Text("Analyzing Drawing")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Our AI is figuring out what you drew...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(32)
        }
    }
    
    // MARK: - Bottom Section
    
    private var bottomSectionView: some View {
        Group {
            if isAnimating {
                // Animation controls
                animationControlsView
            } else if let detected = detectedObject {
                // Animation chooser
                ModernAnimationChooser(
                    detectedObject: detected,
                    onAnimationSelected: startAnimation,
                    onDrawNew: clearDrawing
                )
            } else {
                // Action buttons
                actionButtonsView
            }
        }
    }
    
    private var animationControlsView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                
                Text("Animation in progress...")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
            }
            
            Text("Tap the stop button above to end early")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 20)
        .onTapGesture {
            isAnimating = false
            clearDrawing()
        }
    }
    
    private var actionButtonsView: some View {
        VStack(spacing: 20) {
            if !paths.isEmpty {
                Text("Ready to animate!")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Button(action: analyzeDrawing) {
                HStack(spacing: 12) {
                    Image(systemName: paths.isEmpty ? "wand.and.stars" : "brain.head.profile")
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(paths.isEmpty ? "Draw Something First" : "Analyze & Animate")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(paths.isEmpty ? "Start by drawing on the canvas above" : "Let AI detect your drawing and create animations")
                            .font(.caption)
                            .opacity(0.8)
                    }
                    
                    Spacer()
                    
                    if !paths.isEmpty {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(
                    LinearGradient(
                        colors: paths.isEmpty ? [.gray.opacity(0.6)] : [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .shadow(color: paths.isEmpty ? .clear : .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .disabled(paths.isEmpty || isProcessing)
            .scaleEffect(isProcessing ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isProcessing)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
    
    // MARK: - Body Part Analysis Overlay
    
    private var bodyPartAnalysisOverlay: some View {
        Group {
            if showBodyPartAnalysis {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showBodyPartAnalysis = false
                        }
                    
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Body Part Analysis")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("Technical breakdown of your drawing")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Close") {
                                showBodyPartAnalysis = false
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Color.blue.opacity(0.1),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                        }
                        .padding(20)
                        .background(Color(UIColor.systemGroupedBackground))
                        
                        // Content
                        ScrollView {
                            Text(bodyPartAnalysis)
                                .font(.system(.caption, design: .monospaced))
                                .padding(20)
                        }
                        .frame(maxHeight: 400)
                        .background(.white)
                    }
                    .background(.white)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                    .padding(24)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func clearDrawing() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            paths.removeAll()
            currentPath = DrawingPath()
            detectedObject = nil
            isProcessing = false
            showBodyPartAnalysis = false
        }
    }
    
    private func analyzeAndShowBodyParts() {
        let analysis = ReliableSkeletalAnimator.debugAnalyzePaths(paths)
        bodyPartAnalysis = analysis
    }
    
    private func analyzeDrawing() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isProcessing = true
        }
        
        Task {
            do {
                let detected = try await aiService.analyzeDrawing(paths)
                
                await MainActor.run {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        print("🎯 AI Detected: \(detected.displayName)")
                        detectedObject = detected
                        isProcessing = false
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        print("❌ AI Analysis failed: \(error.localizedDescription)")
                        let detected = ObjectDetector.detectObject(from: paths)
                        detectedObject = detected
                        isProcessing = false
                    }
                }
            }
        }
    }
    
    private func startAnimation(_ animationType: AnimationType) {
        print("🎬 Starting \(animationType.displayName) animation for \(detectedObject?.displayName ?? "unknown")")
        
        // Generate animation frames
        let frames = AnimationGenerator.generateAnimation(
            for: animationType,
            objectType: detectedObject ?? .unknown,
            paths: paths
        )
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            animationFrames = frames
            isAnimating = true
        }
    }
}

// MARK: - Modern Animation Chooser

struct ModernAnimationChooser: View {
    let detectedObject: ObjectType
    let onAnimationSelected: (AnimationType) -> Void
    let onDrawNew: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Detection result header
            HStack(spacing: 16) {
                // Object icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Text(detectedObject.emoji)
                        .font(.system(size: 28))
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.subheadline)
                        
                        Text("Detection Complete")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }
                    
                    Text("I see a \(detectedObject.displayName)!")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Choose an animation to bring it to life:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            // Animation options grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(detectedObject.animations, id: \.self) { animationType in
                    ModernAnimationButton(
                        animationType: animationType,
                        action: { onAnimationSelected(animationType) }
                    )
                }
            }
            .padding(.horizontal, 24)
            
            // Draw new button
            Button(action: onDrawNew) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    
                    Text("Draw Something New")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    Color.blue.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 16)
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .background(.ultraThinMaterial, in: Rectangle())
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

struct ModernAnimationButton: View {
    let animationType: AnimationType
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                action()
            }
        }) {
            VStack(spacing: 12) {
                // Animation emoji with background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.white, .gray.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    Text(animationType.emoji)
                        .font(.system(size: 24))
                }
                
                VStack(spacing: 4) {
                    Text(animationType.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("\(String(format: "%.1f", animationType.duration))s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white)
                    .shadow(color: .black.opacity(isPressed ? 0.05 : 0.1), radius: isPressed ? 2 : 8, x: 0, y: isPressed ? 1 : 4)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Enhanced Debug View

struct DebugView: View {
    let paths: [DrawingPath]
    @State private var testResults: [String] = []
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                Button("Run Model Tests") {
                    runModelTests()
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                
                Button("Analyze Current Drawing") {
                    analyzeCurrentDrawing()
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .disabled(paths.isEmpty)
                .opacity(paths.isEmpty ? 0.6 : 1.0)
            }
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(testResults, id: \.self) { result in
                        Text(result)
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                    }
                }
            }
            .frame(maxHeight: 300)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
        }
        .padding(20)
        .background(.ultraThinMaterial, in: Rectangle())
    }
    
    private func runModelTests() {
        testResults.removeAll()
        
        testResults.append("=== ObjectType Tests ===")
        for objectType in ObjectType.allCases {
            testResults.append("\(objectType.emoji) \(objectType.displayName):")
            for animation in objectType.animations {
                testResults.append("  - \(animation.emoji) \(animation.displayName)")
            }
        }
        
        testResults.append("✅ Model tests completed!")
    }
    
    private func analyzeCurrentDrawing() {
        testResults.removeAll()
        
        if paths.isEmpty {
            testResults.append("No drawing to analyze")
            return
        }
        
        testResults.append("=== Current Drawing Analysis ===")
        let detectedType = ObjectDetector.detectObject(from: paths)
        testResults.append("🎯 Detected: \(detectedType.displayName)")
        
        let info = ObjectDetector.getDetectionInfo(from: paths)
        testResults.append(contentsOf: info.components(separatedBy: "\n"))
        
        testResults.append("\nAvailable animations:")
        for animation in detectedType.animations {
            testResults.append("- \(animation.emoji) \(animation.displayName)")
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
