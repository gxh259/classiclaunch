import CoreGraphics
import Foundation
import ImageIO

let source = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let size = 1024

guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil),
      let context = CGContext(data: nil, width: size, height: size,
                              bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
      let destination = CGImageDestinationCreateWithURL(output as CFURL,
                                                        "public.png" as CFString, 1, nil) else {
    fatalError("Could not prepare the installer icon")
}

context.interpolationQuality = .high
context.draw(image, in: CGRect(x: 100, y: 100, width: 824, height: 824))
context.setFillColor(CGColor(red: 0.10, green: 0.43, blue: 0.95, alpha: 1))
context.fillEllipse(in: CGRect(x: 618, y: 80, width: 300, height: 300))
context.setStrokeColor(CGColor(gray: 1, alpha: 1))
context.setLineWidth(38)
context.setLineCap(.round)
context.setLineJoin(.round)
context.move(to: CGPoint(x: 768, y: 292))
context.addLine(to: CGPoint(x: 768, y: 160))
context.move(to: CGPoint(x: 702, y: 218))
context.addLine(to: CGPoint(x: 768, y: 152))
context.addLine(to: CGPoint(x: 834, y: 218))
context.strokePath()

guard let icon = context.makeImage() else { fatalError("Could not render the installer icon") }
CGImageDestinationAddImage(destination, icon, nil)
guard CGImageDestinationFinalize(destination) else {
    fatalError("Could not save the installer icon")
}
