import SwiftUI

struct DrawingCanvas: View {
    @Binding var paths: [DrawingPath]
    @Binding var currentPath: DrawingPath
    @State private var isDrawing = false
    @State private var lastPoint: CGPoint?
    
    var body: some View {
        Canvas { context, size in
            // Draw all completed paths with enhanced styling
            for (index, drawingPath) in paths.enumerated() {
                // Add subtle shadow for depth
                context.drawLayer(content: { layerContext in
                    layerContext.stroke(
                        drawingPath.path,
                        with: .color(.black.opacity(0.1)),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
                })
                
                // Main stroke with gradient
                let gradient = Gradient(colors: [
                    Color(hue: Double(index) * 0.1, saturation: 0.8, brightness: 0.3),
                    Color(hue: Double(index) * 0.1, saturation: 0.6, brightness: 0.5)
                ])
                
                context.stroke(
                    drawingPath.path,
                    with: .linearGradient(
                        gradient,
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: size.width, y: size.height)
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )
            }
            
            // Draw current path being drawn with special highlight
            if !currentPath.points.isEmpty {
                // Glow effect for current stroke
                context.drawLayer(content: { layerContext in
                    layerContext.stroke(
                        currentPath.path,
                        with: .color(.blue.opacity(0.3)),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round)
                    )
                })
                
                // Main current stroke
                context.stroke(
                    currentPath.path,
                    with: .linearGradient(
                        Gradient(colors: [.blue, .purple]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: size.width, y: size.height)
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )
                
                // Draw touch indicator at current drawing point
                if let lastPoint = lastPoint, isDrawing {
                    // Outer ring
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: lastPoint.x - 12,
                            y: lastPoint.y - 12,
                            width: 24,
                            height: 24
                        )),
                        with: .color(.blue.opacity(0.2))
                    )
                    
                    // Inner dot
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: lastPoint.x - 4,
                            y: lastPoint.y - 4,
                            width: 8,
                            height: 8
                        )),
                        with: .color(.blue)
                    )
                }
            }
        }
        .background(Color.clear)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let point = value.location
                    lastPoint = point
                    
                    if !isDrawing {
                        isDrawing = true
                        currentPath.path.move(to: point)
                        currentPath.points.append(point)
                    } else {
                        // Smooth the path by only adding points at certain intervals
                        if let lastDrawnPoint = currentPath.points.last {
                            let distance = sqrt(pow(point.x - lastDrawnPoint.x, 2) + pow(point.y - lastDrawnPoint.y, 2))
                            
                            // Only add point if it's far enough from the last one for smoother lines
                            if distance > 2.0 {
                                currentPath.path.addLine(to: point)
                                currentPath.points.append(point)
                            }
                        }
                    }
                }
                .onEnded { _ in
                    if !currentPath.points.isEmpty {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            paths.append(currentPath)
                            currentPath = DrawingPath()
                            isDrawing = false
                            lastPoint = nil
                        }
                    }
                }
        )
        .onAppear {
            // Add subtle haptic feedback capability
        }
    }
}

// MARK: - Enhanced Drawing Canvas with Feedback

extension DrawingCanvas {
    
    /// Provides haptic feedback when starting to draw
    private func provideFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Preview

struct DrawingCanvas_Previews: PreviewProvider {
    static var previews: some View {
        @State var paths: [DrawingPath] = []
        @State var currentPath = DrawingPath()
        
        return VStack {
            Text("Enhanced Drawing Canvas")
                .font(.title2)
                .fontWeight(.bold)
                .padding()
            
            DrawingCanvas(paths: $paths, currentPath: $currentPath)
                .frame(height: 400)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                )
                .padding()
            
            HStack {
                Text("Paths: \(paths.count)")
                Spacer()
                Button("Clear") {
                    paths.removeAll()
                    currentPath = DrawingPath()
                }
                .foregroundColor(.red)
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}
