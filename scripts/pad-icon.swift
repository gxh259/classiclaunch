import CoreGraphics
import Foundation
import ImageIO

let source = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let size = 1024
let inset = Int(Double(size) * 0.10)

guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil),
      let context = CGContext(data: nil, width: size, height: size,
                              bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
      let destination = CGImageDestinationCreateWithURL(output as CFURL,
                                                        "public.png" as CFString, 1, nil) else {
    fatalError("Could not prepare the application icon")
}

context.interpolationQuality = .high
context.draw(image, in: CGRect(x: inset, y: inset,
                               width: size - inset * 2, height: size - inset * 2))
guard let paddedIcon = context.makeImage() else {
    fatalError("Could not render the application icon")
}
CGImageDestinationAddImage(destination, paddedIcon, nil)
guard CGImageDestinationFinalize(destination) else {
    fatalError("Could not save the application icon")
}
