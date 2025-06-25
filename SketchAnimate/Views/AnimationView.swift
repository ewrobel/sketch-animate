//
//  AnimationView.swift
//  SketchAnimate
//
//  Created by Emily Wrobel on 6/23/25.
//

import SwiftUI

struct AnimationView: View {
    let animationFrames: [AnimationFrame]
    @State private var currentFrame = 0
    @State private var isPlaying = false
    @State private var animationTimer: Timer?
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Animation Canvas
            Canvas { context, size in
                if currentFrame < animationFrames.count {
                    let frame = animationFrames[currentFrame]
                    
                    // Draw each path in the current frame
                    for animatedPath in frame.paths {
                        context.stroke(
                            animatedPath.path,
                            with: .color(.black),
                            lineWidth: 3.0
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // Animation controls overlay
            VStack {
                Spacer()
                
                HStack {
                    // Frame counter
                    Text("Frame \(currentFrame + 1)/\(animationFrames.count)")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    
                    Spacer()
                    
                    // Animation progress
                    if animationFrames.count > 0 {
                        let progress = Double(currentFrame) / Double(animationFrames.count)
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
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
    
    private func startAnimation() {
        guard !animationFrames.isEmpty && !isPlaying else { return }
        
        print("🎬 Starting animation with \(animationFrames.count) frames")
        isPlaying = true
        currentFrame = 0
        
        // 10 FPS playback
        let frameDuration = 0.1
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: frameDuration, repeats: true) { timer in
            currentFrame += 1
            
            if currentFrame >= animationFrames.count {
                stopAnimation()
                
                // Wait a moment then complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onComplete()
                }
            }
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        isPlaying = false
        print("🎬 Animation stopped")
    }
}

struct AnimationView_Previews: PreviewProvider {
    static var previews: some View {
        // Create sample animation frames for preview
        let samplePath = DrawingPath()
        let sampleFrames = [
            AnimationFrame(paths: [samplePath], frameNumber: 0),
            AnimationFrame(paths: [samplePath], frameNumber: 1)
        ]
        
        return AnimationView(animationFrames: sampleFrames) {
            print("Animation completed")
        }
        .frame(height: 400)
        .padding()
    }
}
