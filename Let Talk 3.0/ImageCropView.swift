import SwiftUI

struct ImageCropView: View {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    private let cropSize: CGFloat = 300
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Instructions
                    Text("Adjust your profile picture")
                        .foregroundColor(.white)
                        .font(.headline)
                        .padding(.top)
                    
                    // Image cropping area
                    ZStack {
                        // Background grid
                        GridBackgroundView()
                        
                        // Cropped image view
                        if let image = image {
                            GeometryReader { geometry in
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .scaleEffect(scale)
                                    .offset(offset)
                                    .clipped()
                            }
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .gesture(
                                SimultaneousGesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            let delta = value / lastScale
                                            lastScale = value
                                            scale = min(max(scale * delta, 0.5), 3.0)
                                        }
                                        .onEnded { _ in
                                            lastScale = 1.0
                                        },
                                    DragGesture()
                                        .onChanged { value in
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                        .onEnded { _ in
                                            lastOffset = offset
                                        }
                                )
                            )
                        }
                    }
                    .frame(width: cropSize, height: cropSize)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Circle())
                    
                    // Controls
                    VStack(spacing: 15) {
                        // Scale control
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Zoom")
                                .foregroundColor(.white)
                                .font(.subheadline)
                            Slider(value: Binding(
                                get: { scale },
                                set: { scale = min(max($0, 0.5), 3.0) }
                            ), in: 0.5...3.0)
                            .accentColor(.blue)
                        }
                        .padding(.horizontal)
                        
                        // Reset button
                        Button(action: {
                            withAnimation(.spring()) {
                                scale = 1.0
                                offset = .zero
                                lastScale = 1.0
                                lastOffset = .zero
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset")
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationTitle("Edit Profile Picture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        cropImage()
                        dismiss()
                    }
                    .foregroundColor(.blue)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            // Initialize with image centered
            if let image = image {
                let imageSize = image.size
                let scaleToFit = min(cropSize / imageSize.width, cropSize / imageSize.height)
                scale = max(scaleToFit, 1.0)
                // Center the image
                offset = .zero
                lastOffset = .zero
            }
        }
    }
    
    private func cropImage() {
        guard let image = image else { return }
        
        // Create a circular crop
        let size = min(image.size.width, image.size.height)
        let scaleFactor = max(cropSize / size, scale)
        
        // Calculate the crop rect in the original image coordinates
        let imageSize = image.size
        let scaledImageSize = CGSize(
            width: imageSize.width * scaleFactor,
            height: imageSize.height * scaleFactor
        )
        
        // Calculate the visible area
        let visibleX = (scaledImageSize.width - cropSize) / 2 - offset.width
        let visibleY = (scaledImageSize.height - cropSize) / 2 - offset.height
        
        // Convert back to original image coordinates
        let cropX = max(0, min(visibleX / scaleFactor, imageSize.width - size))
        let cropY = max(0, min(visibleY / scaleFactor, imageSize.height - size))
        let cropRect = CGRect(x: cropX, y: cropY, width: size, height: size)
        
        // Crop and resize
        if let cgImage = image.cgImage?.cropping(to: cropRect) {
            let cropped = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
            
            // Resize to final size
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropSize, height: cropSize))
            let resized = renderer.image { context in
                // Draw in a circle
                let path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: CGSize(width: cropSize, height: cropSize)))
                path.addClip()
                cropped.draw(in: CGRect(origin: .zero, size: CGSize(width: cropSize, height: cropSize)))
            }
            
            self.image = resized
        }
    }
}

struct GridBackgroundView: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let spacing: CGFloat = 20
                let width = geometry.size.width
                let height = geometry.size.height
                
                // Vertical lines
                var x: CGFloat = 0
                while x < width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                    x += spacing
                }
                
                // Horizontal lines
                var y: CGFloat = 0
                while y < height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                    y += spacing
                }
            }
            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        }
    }
}

