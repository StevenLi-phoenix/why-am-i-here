// Renders the app icon: a blue tile with a white progress ring around a question mark.
// Usage: swift scripts/make_icon.swift App/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import AppKit
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
let s = CGFloat(size)

// noneSkipLast keeps the PNG opaque, which iOS requires for app icons.
guard let cg = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                         space: CGColorSpace(name: CGColorSpace.sRGB)!,
                         bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("could not create bitmap context")
}

// Background: top-lit blue.
let colors = [CGColor(red: 0.16, green: 0.66, blue: 1, alpha: 1), CGColor(red: 0, green: 0.44, blue: 0.94, alpha: 1)]
let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors as CFArray, locations: [0, 1])!
cg.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])

// Ring: faint full track, with a bright arc covering most of it.
let center = CGPoint(x: s / 2, y: s / 2)
let radius: CGFloat = 300
cg.setLineWidth(84)
cg.setLineCap(.round)
cg.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.28))
cg.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
cg.strokePath()
cg.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
// Starts at 12 o'clock and runs clockwise for 72% of the circle.
cg.addArc(center: center, radius: radius, startAngle: .pi / 2, endAngle: .pi / 2 - .pi * 2 * 0.72, clockwise: true)
cg.strokePath()

// Question mark, centred on its glyph bounds.
NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: false)
let font = NSFont.systemFont(ofSize: 380, weight: .heavy)
let text = NSAttributedString(string: "?", attributes: [.font: font, .foregroundColor: NSColor.white])
let line = CTLineCreateWithAttributedString(text)
let glyphBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
cg.textPosition = CGPoint(x: (s - glyphBounds.width) / 2 - glyphBounds.minX,
                          y: (s - glyphBounds.height) / 2 - glyphBounds.minY)
CTLineDraw(line, cg)

guard let image = cg.makeImage(),
      let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: output) as CFURL,
                                                        UTType.png.identifier as CFString, 1, nil) else {
    fatalError("could not create PNG destination")
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("could not write PNG") }
print("wrote \(output)")
