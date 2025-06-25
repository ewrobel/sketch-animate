//
//  AnimationChooser.swift
//  SketchAnimate
//
//  Created by Emily Wrobel on 6/23/25.
//

import SwiftUI

struct AnimationChooser: View {
    let detectedObject: ObjectType
    let onAnimationSelected: (AnimationType) -> Void
    let onDrawNew: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Detection result
            HStack {
                Text(detectedObject.emoji)
                    .font(.system(size: 40))
                
                VStack(alignment: .leading) {
                    Text("I see a \(detectedObject.displayName)!")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Choose an animation:")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            
            // Animation options
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 15) {
                ForEach(detectedObject.animations, id: \.self) { animationType in
                    AnimationButton(
                        animationType: animationType,
                        action: { onAnimationSelected(animationType) }
                    )
                }
            }
            
            // Draw new button
            Button("Draw Something New") {
                onDrawNew()
            }
            .font(.headline)
            .foregroundColor(.blue)
            .padding(.top)
        }
        .padding()
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

struct AnimationButton: View {
    let animationType: AnimationType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(animationType.emoji)
                    .font(.system(size: 30))
                
                Text(animationType.displayName)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text("\(String(format: "%.1f", animationType.duration))s")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(1.0)
        .animation(.easeInOut(duration: 0.1), value: false)
    }
}

struct AnimationChooser_Previews: PreviewProvider {
    static var previews: some View {
        AnimationChooser(
            detectedObject: .human,
            onAnimationSelected: { animationType in
                print("Selected: \(animationType.displayName)")
            },
            onDrawNew: {
                print("Draw new requested")
            }
        )
        .background(Color(.systemGroupedBackground))
    }
}
