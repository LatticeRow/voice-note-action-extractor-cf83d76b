import AppKit

struct BrandColors {
    static let deepNavy = NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.10, alpha: 1)
    static let navyLift = NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.18, alpha: 1)
    static let charcoal = NSColor(calibratedRed: 0.03, green: 0.04, blue: 0.07, alpha: 1)
    static let gold = NSColor(calibratedRed: 0.85, green: 0.73, blue: 0.45, alpha: 1)
    static let goldSoft = NSColor(calibratedRed: 0.96, green: 0.89, blue: 0.67, alpha: 1)
    static let ivory = NSColor(calibratedRed: 0.97, green: 0.95, blue: 0.91, alpha: 1)
}

let fileManager = FileManager.default
let root = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let assets = root.appendingPathComponent("Aureline/Resources/Assets.xcassets")

func imageRep(size: CGFloat, opaque: Bool = false, draw: (CGRect) -> Void) -> NSBitmapImageRep {
    let pixelSize = NSSize(width: size, height: size)
    let image = NSImage(size: pixelSize)
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    draw(CGRect(origin: .zero, size: pixelSize))
    image.unlockFocus()

    guard let rep = NSBitmapImageRep(data: image.tiffRepresentation ?? Data()) else {
        fatalError("Unable to build image representation")
    }
    rep.size = pixelSize
    return rep
}

func savePNG(_ rep: NSBitmapImageRep, to url: URL) throws {
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Unable to serialize PNG")
    }
    try data.write(to: url)
}

func fillRoundedBackground(in rect: CGRect) {
    let roundedRect = NSBezierPath(roundedRect: rect.insetBy(dx: rect.width * 0.02, dy: rect.height * 0.02), xRadius: rect.width * 0.22, yRadius: rect.height * 0.22)
    let gradient = NSGradient(colors: [BrandColors.navyLift, BrandColors.deepNavy, BrandColors.charcoal])!
    gradient.draw(in: roundedRect, angle: -45)

    NSColor.white.withAlphaComponent(0.08).setStroke()
    roundedRect.lineWidth = rect.width * 0.008
    roundedRect.stroke()
}

func drawMark(in rect: CGRect, transparent: Bool) {
    if !transparent {
        fillRoundedBackground(in: rect)
    }

    let inset = rect.width * (transparent ? 0.23 : 0.18)
    let logoRect = rect.insetBy(dx: inset, dy: inset)
    let center = CGPoint(x: logoRect.midX, y: logoRect.midY)
    let radius = logoRect.width * 0.40
    let ring = NSBezierPath()
    ring.lineWidth = logoRect.width * 0.05
    ring.appendArc(withCenter: center, radius: radius, startAngle: 35, endAngle: 325)
    BrandColors.goldSoft.withAlphaComponent(0.9).setStroke()
    ring.stroke()

    let wave = NSBezierPath()
    wave.lineWidth = logoRect.width * 0.062
    wave.lineCapStyle = .round
    wave.lineJoinStyle = .round
    wave.move(to: CGPoint(x: logoRect.minX + logoRect.width * 0.10, y: center.y + logoRect.height * 0.05))
    wave.curve(
        to: CGPoint(x: logoRect.minX + logoRect.width * 0.34, y: center.y - logoRect.height * 0.08),
        controlPoint1: CGPoint(x: logoRect.minX + logoRect.width * 0.18, y: center.y + logoRect.height * 0.20),
        controlPoint2: CGPoint(x: logoRect.minX + logoRect.width * 0.24, y: center.y - logoRect.height * 0.18)
    )
    wave.curve(
        to: CGPoint(x: logoRect.minX + logoRect.width * 0.58, y: center.y + logoRect.height * 0.09),
        controlPoint1: CGPoint(x: logoRect.minX + logoRect.width * 0.42, y: center.y + logoRect.height * 0.02),
        controlPoint2: CGPoint(x: logoRect.minX + logoRect.width * 0.49, y: center.y + logoRect.height * 0.18)
    )
    wave.curve(
        to: CGPoint(x: logoRect.minX + logoRect.width * 0.88, y: center.y - logoRect.height * 0.02),
        controlPoint1: CGPoint(x: logoRect.minX + logoRect.width * 0.67, y: center.y - logoRect.height * 0.18),
        controlPoint2: CGPoint(x: logoRect.minX + logoRect.width * 0.78, y: center.y + logoRect.height * 0.04)
    )
    BrandColors.gold.setStroke()
    wave.stroke()

    let anchorSize = logoRect.width * 0.10
    let anchorRect = CGRect(
        x: logoRect.maxX - anchorSize * 1.2,
        y: center.y - anchorSize * 0.5,
        width: anchorSize,
        height: anchorSize
    )
    let anchor = NSBezierPath(ovalIn: anchorRect)
    BrandColors.ivory.setFill()
    anchor.fill()

    let glow = NSBezierPath(ovalIn: anchorRect.insetBy(dx: -anchorSize * 0.45, dy: -anchorSize * 0.45))
    BrandColors.gold.withAlphaComponent(0.18).setFill()
    glow.fill()
}

let masterAppIcon = assets.appendingPathComponent("AppIcon.appiconset/AppIcon-1024.png")
let masterLaunchBrand = assets.appendingPathComponent("LaunchBrand.imageset/LaunchBrand@3x.png")

try savePNG(imageRep(size: 1024) { rect in
    drawMark(in: rect, transparent: false)
}, to: masterAppIcon)

try savePNG(imageRep(size: 1536) { rect in
    NSColor.clear.setFill()
    rect.fill()
    drawMark(in: rect, transparent: true)
}, to: masterLaunchBrand)
