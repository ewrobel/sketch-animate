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
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SketchAnimate")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                HStack(spacing: 15) {
                    Button("Debug") {
                        showingTests.toggle()
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    
                    Button("Clear") {
                        clearDrawing()
                    }
                    .font(.headline)
                    .foregroundColor(.red)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            
            if showingTests {
                // Debug/Test Results
                DebugView(paths: paths)
                    .transition(.move(edge: .top))
            } else {
                // Main content
                ZStack {
                    if isAnimating {
                        // Show animation
                        AnimationView(animationFrames: animationFrames) {
                            // Animation completed
                            isAnimating = false
                            clearDrawing()
                        }
                        .padding()
                    } else {
                        // Drawing Canvas
                        DrawingCanvas(paths: $paths, currentPath: $currentPath)
                            .frame(maxHeight: .infinity)
                            .padding()
                        
                        // Processing overlay
                        if isProcessing {
                            ZStack {
                                Color.black.opacity(0.3)
                                
                                VStack(spacing: 20) {
                                    ProgressView()
                                        .scaleEffect(2)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    
                                    Text("Analyzing your drawing...")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .fontWeight(.medium)
                                }
                            }
                            .cornerRadius(12)
                            .padding()
                        }
                    }
                }
                
                // Bottom section
                if isAnimating {
                    // Show animation is playing
                    VStack {
                        Text("🎬 Animation Playing...")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        Text("Tap anywhere to stop")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .onTapGesture {
                        isAnimating = false
                        clearDrawing()
                    }
                } else if let detected = detectedObject {
                    // Show animation chooser
                    AnimationChooser(
                        detectedObject: detected,
                        onAnimationSelected: { animationType in
                            startAnimation(animationType)
                        },
                        onDrawNew: {
                            clearDrawing()
                        }
                    )
                } else {
                    // Show analyze buttons
                    VStack(spacing: 20) {
                        if !paths.isEmpty {
                            Text("Drawing has \(paths.count) stroke\(paths.count == 1 ? "" : "s")")
                                .font(.headline)
                                .foregroundColor(.gray)
                        } else {
                            Text("Draw something with your finger!")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                        
                        // Two buttons side by side
                        HStack(spacing: 15) {
                            Button(action: analyzeDrawing) {
                                Text("Analyze Drawing")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(paths.isEmpty ? Color.gray : Color.blue)
                                    .cornerRadius(12)
                            }
                            .disabled(paths.isEmpty || isProcessing)
                            
                            Button("Show Body Parts") {
                                if !paths.isEmpty {
                                    analyzeAndShowBodyParts()
                                    showBodyPartAnalysis.toggle()
                                }
                            }
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(paths.isEmpty ? Color.gray : Color.purple)
                            .cornerRadius(12)
                            .disabled(paths.isEmpty)
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .overlay(
            // Body part analysis overlay
            Group {
                if showBodyPartAnalysis {
                    VStack {
                        ScrollView {
                            Text("Body Part Analysis")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding()
                            
                            Text(bodyPartAnalysis)
                                .font(.system(.caption, design: .monospaced))
                                .padding()
                                .background(Color.black.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .frame(maxHeight: 300)
                        
                        Button("Close") {
                            showBodyPartAnalysis = false
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 5)
                    .transition(.scale)
                }
            }
        )
        .animation(.easeInOut(duration: 0.3), value: showingTests)
        .animation(.easeInOut(duration: 0.3), value: detectedObject)
        .animation(.easeInOut(duration: 0.3), value: showBodyPartAnalysis)
    }
    
    // MARK: - Helper Functions
    
    private func clearDrawing() {
        paths.removeAll()
        currentPath = DrawingPath()
        detectedObject = nil
        isProcessing = false
        showBodyPartAnalysis = false
    }
    
    private func analyzeAndShowBodyParts() {
        let analysis = ReliableSkeletalAnimator.debugAnalyzePaths(paths)
        bodyPartAnalysis = analysis
    }
    
    private func analyzeDrawing() {
        isProcessing = true
        
        Task {
            do {
                let detected = try await aiService.analyzeDrawing(paths)
                
                await MainActor.run {
                    print("🎯 AI Detected: \(detected.displayName)")
                    detectedObject = detected
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    print("❌ AI Analysis failed: \(error.localizedDescription)")
                    // Fallback to simple local detection
                    let detected = ObjectDetector.detectObject(from: paths)
                    detectedObject = detected
                    isProcessing = false
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
        
        animationFrames = frames
        isAnimating = true
    }
}

// MARK: - Debug View

struct DebugView: View {
    let paths: [DrawingPath]
    @State private var testResults: [String] = []
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Button("Run Model Tests") {
                    runModelTests()
                }
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Button("Analyze Current Drawing") {
                    analyzeCurrentDrawing()
                }
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(paths.isEmpty)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(testResults, id: \.self) { result in
                        Text(result)
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
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
