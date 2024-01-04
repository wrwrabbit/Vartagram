import Foundation
import AVFoundation
import UIKit
import CoreImage
import Metal
import MetalKit
import Display
import SwiftSignalKit
import TelegramCore
import Postbox

public func mediaEditorGenerateGradientImage(size: CGSize, colors: [UIColor]) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
    if let context = UIGraphicsGetCurrentContext() {
        let gradientColors = colors.map { $0.cgColor } as CFArray
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        var locations: [CGFloat] = [0.0, 1.0]
        let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
    }
    
    let image = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()
    
    return image
}

public func mediaEditorGetGradientColors(from image: UIImage) -> MediaEditor.GradientColors {
    let context = DrawingContext(size: CGSize(width: 5.0, height: 5.0), scale: 1.0, clear: false)!
    context.withFlippedContext({ context in
        if let cgImage = image.cgImage {
            context.draw(cgImage, in: CGRect(x: 0.0, y: 0.0, width: 5.0, height: 5.0))
        }
    })
    return MediaEditor.GradientColors(
        top: context.colorAt(CGPoint(x: 2.0, y: 0.0)),
        bottom: context.colorAt(CGPoint(x: 2.0, y: 4.0))
    )
}

final class MediaEditorComposer {
    enum Input {
        case texture(MTLTexture, CMTime)
        case videoBuffer(VideoPixelBuffer)
        
        var timestamp: CMTime {
            switch self {
            case let .texture(_, timestamp):
                return timestamp
            case let .videoBuffer(videoBuffer):
                return videoBuffer.timestamp
            }
        }
        
        var rendererInput: MediaEditorRenderer.Input {
            switch self {
            case let .texture(texture, time):
                return .texture(texture, time)
            case let .videoBuffer(videoBuffer):
                return .videoBuffer(videoBuffer)
            }
        }
    }
    
    let device: MTLDevice?
    private let colorSpace: CGColorSpace
    
    private let values: MediaEditorValues
    private let dimensions: CGSize
    private let outputDimensions: CGSize
    private let textScale: CGFloat
    
    private let ciContext: CIContext?
    private var textureCache: CVMetalTextureCache?
    
    private let renderer = MediaEditorRenderer()
    private let renderChain = MediaEditorRenderChain()
    
    private let drawingImage: CIImage?
    private var entities: [MediaEditorComposerEntity]
    
    init(
        postbox: Postbox,
        values: MediaEditorValues,
        dimensions: CGSize,
        outputDimensions: CGSize,
        textScale: CGFloat,
        videoDuration: Double?,
        additionalVideoDuration: Double?
    ) {
        self.values = values
        self.dimensions = dimensions
        self.outputDimensions = outputDimensions
        self.textScale = textScale
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        self.colorSpace = colorSpace
        
        self.renderer.addRenderChain(self.renderChain)
        
        if let drawing = values.drawing, let drawingImage = CIImage(image: drawing, options: [.colorSpace: self.colorSpace]) {
            self.drawingImage = drawingImage.transformed(by: CGAffineTransform(translationX: -dimensions.width / 2.0, y: -dimensions.height / 2.0))
        } else {
            self.drawingImage = nil
        }
        
        var entities: [MediaEditorComposerEntity] = []
        for entity in values.entities {
            entities.append(contentsOf: composerEntitiesForDrawingEntity(postbox: postbox, textScale: textScale, entity: entity.entity, colorSpace: colorSpace))
        }
        self.entities = entities
        
        self.device = MTLCreateSystemDefaultDevice()
        if let device = self.device {
            self.ciContext = CIContext(mtlDevice: device, options: [.workingColorSpace : self.colorSpace])
            
            CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &self.textureCache)
        } else {
            self.ciContext = nil
        }
                
        self.renderer.setupForComposer(composer: self)
        self.renderChain.update(values: self.values)
        self.renderer.videoFinishPass.update(values: self.values, videoDuration: videoDuration, additionalVideoDuration: additionalVideoDuration)
    }
        
    var previousAdditionalInput: Input?
    func process(main: Input, additional: Input?, timestamp: CMTime, pool: CVPixelBufferPool?, completion: @escaping (CVPixelBuffer?) -> Void) {
        guard let pool, let ciContext = self.ciContext else {
            completion(nil)
            return
        }
        
        var additional = additional
        if let additional {
            self.previousAdditionalInput = additional
        } else {
            additional = self.previousAdditionalInput
        }
        
        self.renderer.consume(main: main.rendererInput, additional: additional?.rendererInput, render: true)
        
        if let resultTexture = self.renderer.resultTexture, var ciImage = CIImage(mtlTexture: resultTexture, options: [.colorSpace: self.colorSpace]) {
            ciImage = ciImage.transformed(by: CGAffineTransformMakeScale(1.0, -1.0).translatedBy(x: 0.0, y: -ciImage.extent.height))
            
            var pixelBuffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
            
            if let pixelBuffer {                
                makeEditorImageFrameComposition(context: ciContext, inputImage: ciImage, drawingImage: self.drawingImage, dimensions: self.dimensions, outputDimensions: self.outputDimensions, values: self.values, entities: self.entities, time: timestamp, completion: { compositedImage in
                    if var compositedImage {
                        let scale = self.outputDimensions.width / compositedImage.extent.width
                        compositedImage = compositedImage.samplingLinear().transformed(by: CGAffineTransform(scaleX: scale, y: scale))

                        self.ciContext?.render(compositedImage, to: pixelBuffer)
                        completion(pixelBuffer)
                    } else {
                        completion(nil)
                    }
                })
                return
            }
        }
        completion(nil)
    }
    
    private var cachedTexture: MTLTexture?
    func textureForImage(_ image: UIImage) -> MTLTexture? {
        if let cachedTexture = self.cachedTexture {
            return cachedTexture
        }
        if let device = self.device, let texture = loadTexture(image: image, device: device) {
            self.cachedTexture = texture
            return texture
        }
        return nil
    }
}

public func makeEditorImageComposition(context: CIContext, postbox: Postbox, inputImage: UIImage, dimensions: CGSize, values: MediaEditorValues, time: CMTime, textScale: CGFloat, completion: @escaping (UIImage?) -> Void) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let inputImage = CIImage(image: inputImage, options: [.colorSpace: colorSpace])!
    var drawingImage: CIImage?
    
    if let drawing = values.drawing, let image = CIImage(image: drawing, options: [.colorSpace: colorSpace]) {
        drawingImage = image.transformed(by: CGAffineTransform(translationX: -dimensions.width / 2.0, y: -dimensions.height / 2.0))
    }
    
    var entities: [MediaEditorComposerEntity] = []
    for entity in values.entities {
        entities.append(contentsOf: composerEntitiesForDrawingEntity(postbox: postbox, textScale: textScale, entity: entity.entity, colorSpace: colorSpace))
    }
    
    makeEditorImageFrameComposition(context: context, inputImage: inputImage, drawingImage: drawingImage, dimensions: dimensions, outputDimensions: dimensions, values: values, entities: entities, time: time, textScale: textScale, completion: { ciImage in
        if let ciImage {
            if let cgImage = context.createCGImage(ciImage, from: CGRect(origin: .zero, size: ciImage.extent.size)) {
                Queue.mainQueue().async {
                    completion(UIImage(cgImage: cgImage))
                }
                return
            }
        }
        completion(nil)
    })
}

private func makeEditorImageFrameComposition(context: CIContext, inputImage: CIImage, drawingImage: CIImage?, dimensions: CGSize, outputDimensions: CGSize, values: MediaEditorValues, entities: [MediaEditorComposerEntity], time: CMTime, textScale: CGFloat = 1.0, completion: @escaping (CIImage?) -> Void) {
    var resultImage = CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: dimensions)).transformed(by: CGAffineTransform(translationX: -dimensions.width / 2.0, y: -dimensions.height / 2.0))
    
    var mediaImage = inputImage.samplingLinear().transformed(by: CGAffineTransform(translationX: -inputImage.extent.midX, y: -inputImage.extent.midY))
    
    var initialScale: CGFloat
    if mediaImage.extent.height > mediaImage.extent.width && values.isStory {
        initialScale = max(dimensions.width / mediaImage.extent.width, dimensions.height / mediaImage.extent.height)
    } else {
        initialScale = dimensions.width / mediaImage.extent.width
    }
    
    if values.isStory {
        resultImage = mediaImage.samplingLinear().composited(over: resultImage)
    } else {
        var horizontalScale = initialScale
        if values.cropMirroring {
            horizontalScale *= -1.0
        }
        mediaImage = mediaImage.transformed(by: CGAffineTransformMakeScale(horizontalScale, initialScale))
        resultImage = mediaImage.composited(over: resultImage)
    }
    
    if let drawingImage {
        resultImage = drawingImage.samplingLinear().composited(over: resultImage)
    }
    
    let frameRate: Float = 30.0
    
    let entitiesCount = Atomic<Int>(value: 1)
    let entitiesImages = Atomic<[(CIImage, Int)]>(value: [])
    let maybeFinalize = {
        let count = entitiesCount.modify { current -> Int in
            return current - 1
        }
        if count == 0 {
            let sortedImages = entitiesImages.with({ $0 }).sorted(by: { $0.1 < $1.1 }).map({ $0.0 })
            for image in sortedImages {
                resultImage = image.composited(over: resultImage)
            }
            
            resultImage = resultImage.transformed(by: CGAffineTransform(translationX: dimensions.width / 2.0, y: dimensions.height / 2.0))
            if values.isStory {
                resultImage = resultImage.cropped(to: CGRect(origin: .zero, size: dimensions))
            } else {
                let originalDimensions = values.originalDimensions.cgSize
                var cropRect = values.cropRect ?? .zero
                if cropRect.isEmpty {
                    cropRect = CGRect(origin: .zero, size: originalDimensions)
                }
                let scale = dimensions.width / originalDimensions.width
                let scaledCropRect = CGRect(origin: CGPoint(x: cropRect.minX * scale, y: dimensions.height - cropRect.maxY * scale), size: CGSize(width: cropRect.width * scale, height: cropRect.height * scale))
                resultImage = resultImage.cropped(to: scaledCropRect)
                resultImage = resultImage.transformed(by: CGAffineTransformMakeTranslation(-scaledCropRect.minX, -scaledCropRect.minY))
                
                if let orientation = values.cropOrientation, orientation != .up {
                    let rotation = orientation.rotation
                    resultImage = resultImage.transformed(by: CGAffineTransformMakeTranslation(-resultImage.extent.width / 2.0, -resultImage.extent.height / 2.0))
                    resultImage = resultImage.transformed(by: CGAffineTransformMakeRotation(rotation))
                    resultImage = resultImage.transformed(by: CGAffineTransformMakeTranslation(resultImage.extent.width / 2.0, resultImage.extent.height / 2.0))
                }
            }
            completion(resultImage)
        }
    }
    var i = 0
    for entity in entities {
        let _ = entitiesCount.modify { current -> Int in
            return current + 1
        }
        let index = i
        entity.image(for: time, frameRate: frameRate, context: context, completion: { image in
            if var image = image?.samplingLinear() {
                let resetTransform = CGAffineTransform(translationX: -image.extent.width / 2.0, y: -image.extent.height / 2.0)
                image = image.transformed(by: resetTransform)
                
                var baseScale: CGFloat = 1.0
                if let scale = entity.baseScale {
                    baseScale = scale
                } else if let _ = entity.baseDrawingSize {
                } else if let baseSize = entity.baseSize {
                    baseScale = baseSize.width / image.extent.width
                }
                
                var transform = CGAffineTransform.identity
                transform = transform.translatedBy(x: -dimensions.width / 2.0 + entity.position.x, y: dimensions.height / 2.0 + entity.position.y * -1.0)
                transform = transform.rotated(by: -entity.rotation)
                transform = transform.scaledBy(x: entity.scale * baseScale, y: entity.scale * baseScale)
                if entity.mirrored {
                    transform = transform.scaledBy(x: -1.0, y: 1.0)
                }
                                                            
                image = image.transformed(by: transform)
                let _ = entitiesImages.modify { current in
                    var updated = current
                    updated.append((image, index))
                    return updated
                }
            }
            maybeFinalize()
        })
        i += 1
    }
    maybeFinalize()
}
