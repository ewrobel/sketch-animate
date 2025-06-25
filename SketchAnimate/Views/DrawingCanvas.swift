//
//  DrawingCanvas.swift
//  SketchAnimate
//
//  Created by Emily Wrobel on 6/23/25.
//
import SwiftUI

struct DrawingCanvas: View {
    @Binding var paths: [DrawingPath]
    @Binding var currentPath: DrawingPath
    
    var body: some View {
        Canvas { context, size in
            // Draw all completed paths
            for drawingPath in paths {
                context.stroke(
                    drawingPath.path,
                    with: .color(.black),
                    lineWidth: 3
                )
            }
            
            // Draw current path being drawn
            context.stroke(
                currentPath.path,
                with: .color(.black),
                lineWidth: 3
            )
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let point = value.location
                    
                    if currentPath.points.isEmpty {
                        currentPath.path.move(to: point)
                    } else {
                        currentPath.path.addLine(to: point)
                    }
                    currentPath.points.append(point)
                }
                .onEnded { _ in
                    if !currentPath.points.isEmpty {
                        paths.append(currentPath)
                        currentPath = DrawingPath()
                    }
                }
        )
    }
}

struct DrawingCanvas_Previews: PreviewProvider {
    static var previews: some View {
        @State var paths: [DrawingPath] = []
        @State var currentPath = DrawingPath()
        
        return DrawingCanvas(paths: $paths, currentPath: $currentPath)
            .frame(height: 400)
            .padding()
    }
}
