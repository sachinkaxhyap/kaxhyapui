//
//  ImageCompressor.swift
//  KaxhyapUI
//
//  Created by Sachin Kaxhyap on 09/01/2026.
//

import Foundation

// MARK: - Constants

private enum CompressionConstants {
    static let maxDimension: CGFloat = 4096
    static let binarySearchIterations = 10
    static let minQuality: CGFloat = 0.1
    static let maxQuality: CGFloat = 0.95
    static let resizeStepFactor: CGFloat = 0.9
    static let resizeCompressionQuality: CGFloat = 0.7
    static let fallbackQuality: CGFloat = 0.1
    static let maxResizeAttempts = 5
}

#if canImport(UIKit)
import UIKit

// MARK: - UIImage Extension (iOS, tvOS, Catalyst)

public extension UIImage {
    
    /// Compresses the image to fit within the specified maximum file size.
    ///
    /// This method uses binary search to find the optimal JPEG compression quality
    /// that produces an image close to but not exceeding the target size.
    /// For very large images, it first scales down to prevent memory issues.
    ///
    /// - Parameter maxSizeKB: The maximum file size in kilobytes (KB). Must be greater than 0.
    /// - Returns: Compressed image data as `Data`, or `nil` if compression fails or input is invalid.
    ///
    /// ```swift
    /// let originalImage: UIImage = // ... from camera, picker, etc.
    /// if let compressedData = originalImage.compressedTo(maxSizeKB: 500) {
    ///     // Upload compressedData to server or save
    /// }
    /// ```
    func compressedTo(maxSizeKB: Int) -> Data? {
        // Input validation
        guard maxSizeKB > 0 else { return nil }
        
        let maxBytes = maxSizeKB * 1024
        
        // First, ensure image dimensions are within limits to prevent memory issues
        let workingImage = constrainedToMaxDimension()
        
        // Try with high quality first
        guard let initialData = workingImage.jpegData(compressionQuality: CompressionConstants.maxQuality) else {
            return nil
        }
        
        // If already under the limit, return as-is
        if initialData.count <= maxBytes {
            return initialData
        }
        
        // Binary search for optimal compression quality
        var minQuality = CompressionConstants.minQuality
        var maxQuality = CompressionConstants.maxQuality
        var bestData: Data?
        
        for _ in 0..<CompressionConstants.binarySearchIterations {
            let midQuality = (minQuality + maxQuality) / 2
            
            guard let compressedData = workingImage.jpegData(compressionQuality: midQuality) else {
                break
            }
            
            if compressedData.count <= maxBytes {
                bestData = compressedData
                minQuality = midQuality // Try higher quality
            } else {
                maxQuality = midQuality // Need lower quality
            }
        }
        
        // If binary search found a valid result, use it
        if let bestData = bestData {
            return bestData
        }
        
        // Fallback: if compression alone isn't enough, resize the image
        return workingImage.compressedByResizing(maxSizeKB: maxSizeKB)
    }
    
    /// Asynchronously compresses the image to fit within the specified maximum file size.
    ///
    /// Useful for large images to avoid blocking the main thread.
    ///
    /// - Parameter maxSizeKB: The maximum file size in kilobytes (KB). Must be greater than 0.
    /// - Returns: Compressed image data as `Data`, or `nil` if compression fails or input is invalid.
    func compressedTo(maxSizeKB: Int) async -> Data? {
        await Task.detached(priority: .userInitiated) { [self] in
            self.compressedTo(maxSizeKB: maxSizeKB)
        }.value
    }
    
    /// Constrains the image to maximum dimensions to prevent memory issues.
    private func constrainedToMaxDimension() -> UIImage {
        let maxDim = CompressionConstants.maxDimension
        let maxSide = max(size.width, size.height)
        
        guard maxSide > maxDim else {
            return self
        }
        
        let scale = maxDim / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        return resized(to: newSize) ?? self
    }
    
    /// Compresses by resizing the image progressively until it fits the target size.
    private func compressedByResizing(maxSizeKB: Int) -> Data? {
        let maxBytes = maxSizeKB * 1024
        var currentImage = self
        
        // Calculate approximate scale needed based on current size vs target
        if let currentData = currentImage.jpegData(compressionQuality: CompressionConstants.resizeCompressionQuality) {
            let currentBytes = currentData.count
            if currentBytes > maxBytes {
                // Estimate scale factor: sqrt because area scales quadratically
                let estimatedScale = sqrt(Double(maxBytes) / Double(currentBytes)) * 0.9
                if estimatedScale < 1.0 && estimatedScale > 0.1 {
                    let newSize = CGSize(
                        width: currentImage.size.width * estimatedScale,
                        height: currentImage.size.height * estimatedScale
                    )
                    if let resizedImage = currentImage.resized(to: newSize),
                       let imageData = resizedImage.jpegData(compressionQuality: CompressionConstants.resizeCompressionQuality),
                       imageData.count <= maxBytes {
                        return imageData
                    }
                }
            }
        }
        
        // Progressive resizing as fallback
        var scaleFactor: CGFloat = CompressionConstants.resizeStepFactor
        var attempts = 0
        
        while scaleFactor > 0.1 && attempts < CompressionConstants.maxResizeAttempts {
            attempts += 1
            
            let newSize = CGSize(
                width: currentImage.size.width * scaleFactor,
                height: currentImage.size.height * scaleFactor
            )
            
            guard let resizedImage = currentImage.resized(to: newSize),
                  let imageData = resizedImage.jpegData(compressionQuality: CompressionConstants.resizeCompressionQuality) else {
                break
            }
            
            if imageData.count <= maxBytes {
                return imageData
            }
            
            currentImage = resizedImage
            scaleFactor *= CompressionConstants.resizeStepFactor
        }
        
        // Last resort: minimum quality at current size
        return currentImage.jpegData(compressionQuality: CompressionConstants.fallbackQuality)
    }
    
    /// Resizes the image to the specified size.
    private func resized(to targetSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

#endif

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

// MARK: - NSImage Extension (macOS)

public extension NSImage {
    
    /// Compresses the image to fit within the specified maximum file size.
    ///
    /// This method uses binary search to find the optimal JPEG compression quality
    /// that produces an image close to but not exceeding the target size.
    /// For very large images, it first scales down to prevent memory issues.
    ///
    /// - Parameter maxSizeKB: The maximum file size in kilobytes (KB). Must be greater than 0.
    /// - Returns: Compressed image data as `Data`, or `nil` if compression fails or input is invalid.
    ///
    /// ```swift
    /// let originalImage: NSImage = // ... from file, pasteboard, etc.
    /// if let compressedData = originalImage.compressedTo(maxSizeKB: 500) {
    ///     // Upload compressedData to server or save
    /// }
    /// ```
    func compressedTo(maxSizeKB: Int) -> Data? {
        // Input validation
        guard maxSizeKB > 0 else { return nil }
        
        let maxBytes = maxSizeKB * 1024
        
        // First, ensure image dimensions are within limits to prevent memory issues
        let workingImage = constrainedToMaxDimension()
        
        // Get bitmap representation
        guard let tiffData = workingImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        // Try with high quality first
        guard let initialData = bitmapRep.representation(
            using: .jpeg,
            properties: [.compressionFactor: CompressionConstants.maxQuality]
        ) else {
            return nil
        }
        
        // If already under the limit, return as-is
        if initialData.count <= maxBytes {
            return initialData
        }
        
        // Binary search for optimal compression quality
        var minQuality = CompressionConstants.minQuality
        var maxQuality = CompressionConstants.maxQuality
        var bestData: Data?
        
        for _ in 0..<CompressionConstants.binarySearchIterations {
            let midQuality = (minQuality + maxQuality) / 2
            
            guard let compressedData = bitmapRep.representation(
                using: .jpeg,
                properties: [.compressionFactor: midQuality]
            ) else {
                break
            }
            
            if compressedData.count <= maxBytes {
                bestData = compressedData
                minQuality = midQuality // Try higher quality
            } else {
                maxQuality = midQuality // Need lower quality
            }
        }
        
        // If binary search found a valid result, use it
        if let bestData = bestData {
            return bestData
        }
        
        // Fallback: if compression alone isn't enough, resize the image
        return workingImage.compressedByResizing(maxSizeKB: maxSizeKB)
    }
    
    /// Asynchronously compresses the image to fit within the specified maximum file size.
    ///
    /// Useful for large images to avoid blocking the main thread.
    ///
    /// - Parameter maxSizeKB: The maximum file size in kilobytes (KB). Must be greater than 0.
    /// - Returns: Compressed image data as `Data`, or `nil` if compression fails or input is invalid.
    func compressedTo(maxSizeKB: Int) async -> Data? {
        await Task.detached(priority: .userInitiated) { [self] in
            self.compressedTo(maxSizeKB: maxSizeKB)
        }.value
    }
    
    /// Constrains the image to maximum dimensions to prevent memory issues.
    private func constrainedToMaxDimension() -> NSImage {
        let maxDim = CompressionConstants.maxDimension
        let maxSide = max(size.width, size.height)
        
        guard maxSide > maxDim else {
            return self
        }
        
        let scale = maxDim / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        return resized(to: newSize) ?? self
    }
    
    /// Compresses by resizing the image progressively until it fits the target size.
    private func compressedByResizing(maxSizeKB: Int) -> Data? {
        let maxBytes = maxSizeKB * 1024
        var currentImage = self
        
        // Calculate approximate scale needed based on current size vs target
        if let tiffData = currentImage.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let currentData = bitmapRep.representation(
               using: .jpeg,
               properties: [.compressionFactor: CompressionConstants.resizeCompressionQuality]
           ) {
            let currentBytes = currentData.count
            if currentBytes > maxBytes {
                // Estimate scale factor: sqrt because area scales quadratically
                let estimatedScale = sqrt(Double(maxBytes) / Double(currentBytes)) * 0.9
                if estimatedScale < 1.0 && estimatedScale > 0.1 {
                    let newSize = CGSize(
                        width: currentImage.size.width * estimatedScale,
                        height: currentImage.size.height * estimatedScale
                    )
                    if let resizedImage = currentImage.resized(to: newSize),
                       let resizedTiff = resizedImage.tiffRepresentation,
                       let resizedBitmap = NSBitmapImageRep(data: resizedTiff),
                       let imageData = resizedBitmap.representation(
                           using: .jpeg,
                           properties: [.compressionFactor: CompressionConstants.resizeCompressionQuality]
                       ),
                       imageData.count <= maxBytes {
                        return imageData
                    }
                }
            }
        }
        
        // Progressive resizing as fallback
        var scaleFactor: CGFloat = CompressionConstants.resizeStepFactor
        var attempts = 0
        
        while scaleFactor > 0.1 && attempts < CompressionConstants.maxResizeAttempts {
            attempts += 1
            
            let newSize = CGSize(
                width: currentImage.size.width * scaleFactor,
                height: currentImage.size.height * scaleFactor
            )
            
            guard let resizedImage = currentImage.resized(to: newSize),
                  let tiffData = resizedImage.tiffRepresentation,
                  let bitmapRep = NSBitmapImageRep(data: tiffData),
                  let imageData = bitmapRep.representation(
                      using: .jpeg,
                      properties: [.compressionFactor: CompressionConstants.resizeCompressionQuality]
                  ) else {
                break
            }
            
            if imageData.count <= maxBytes {
                return imageData
            }
            
            currentImage = resizedImage
            scaleFactor *= CompressionConstants.resizeStepFactor
        }
        
        // Last resort: minimum quality at current size
        guard let tiffData = currentImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        return bitmapRep.representation(
            using: .jpeg,
            properties: [.compressionFactor: CompressionConstants.fallbackQuality]
        )
    }
    
    /// Resizes the image to the specified size using modern NSGraphicsContext approach.
    private func resized(to targetSize: CGSize) -> NSImage? {
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(targetSize.width),
            pixelsHigh: Int(targetSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        
        bitmapRep.size = targetSize
        
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
        NSGraphicsContext.current?.imageInterpolation = .high
        
        self.draw(
            in: CGRect(origin: .zero, size: targetSize),
            from: CGRect(origin: .zero, size: self.size),
            operation: .copy,
            fraction: 1.0
        )
        
        let newImage = NSImage(size: targetSize)
        newImage.addRepresentation(bitmapRep)
        return newImage
    }
}

#endif
