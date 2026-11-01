//
//  icone_ballon.swift
//  Ligue1
//  © 2026 Stephen O'Donnell, Tanguy Labbe · GNU GPL v3 ou ultérieure (fichier LICENSE).
//
//  Dessine l'icône de l'app (ballon sur une pelouse, 1024 px) :
//    swift outils/icone_ballon.swift Assets.xcassets/AppIcon.appiconset/ballon.png
//  Hors de la racine : build.sh ne compile que les *.swift du dossier principal.
//
import AppKit

let taille: CGFloat = 1024
let sortie = CommandLine.arguments.dropFirst().first ?? "ballon.png"

func couleur(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

func degrade(_ couleurs: [CGColor], _ positions: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
               colors: couleurs as CFArray, locations: positions)!
}

func rectArrondi(_ r: CGRect, _ rayon: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: rayon, cornerHeight: rayon, transform: nil)
}

/// Pentagone régulier : centre, rayon, angle du premier sommet (radians).
func pentagone(_ c: CGPoint, _ r: CGFloat, _ angle: CGFloat) -> [CGPoint] {
    (0..<5).map { k in
        let a = angle + CGFloat(k) * 2 * .pi / 5
        return CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
    }
}

func polygone(_ points: [CGPoint]) -> CGPath {
    let p = CGMutablePath()
    p.addLines(between: points)
    p.closeSubpath()
    return p
}

guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(taille), pixelsHigh: Int(taille),
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
      let contexte = NSGraphicsContext(bitmapImageRep: rep) else { exit(1) }
let ctx = contexte.cgContext
NSGraphicsContext.current = contexte

// Repère haut-gauche, comme une maquette.
ctx.translateBy(x: 0, y: taille)
ctx.scaleBy(x: 1, y: -1)

// MARK: Fond — carré arrondi de la grille d'icônes macOS (824 px dans 1024)

let fond = CGRect(x: 100, y: 100, width: 824, height: 824)
let formeFond = rectArrondi(fond, 185)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 12), blur: 28, color: couleur(0x000000, 0.35))
ctx.addPath(formeFond)
ctx.setFillColor(couleur(0x1D6B35))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(formeFond)
ctx.clip()

// Pelouse : dégradé, bandes de tonte, éclairage en haut à gauche.
ctx.drawLinearGradient(degrade([couleur(0x4CB86A), couleur(0x2E9450), couleur(0x16602C)], [0, 0.5, 1]),
                       start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: [])
for i in stride(from: 0, to: 8, by: 2) {
    ctx.setFillColor(couleur(0xFFFFFF, 0.06))
    ctx.fill(CGRect(x: 100 + CGFloat(i) * 103, y: 100, width: 103, height: 824))
}
ctx.drawRadialGradient(degrade([couleur(0xFFFFFF, 0.25), couleur(0xFFFFFF, 0)], [0, 1]),
                       startCenter: CGPoint(x: 330, y: 240), startRadius: 0,
                       endCenter: CGPoint(x: 330, y: 240), endRadius: 560, options: [])

// Lignes du terrain : médiane et rond central.
ctx.setStrokeColor(couleur(0xFFFFFF, 0.75))
ctx.setLineWidth(14)
ctx.move(to: CGPoint(x: 100, y: 512))
ctx.addLine(to: CGPoint(x: 924, y: 512))
ctx.strokePath()
ctx.addEllipse(in: CGRect(x: 512 - 300, y: 512 - 300, width: 600, height: 600))
ctx.strokePath()
ctx.restoreGState()

// MARK: Ballon

let centre = CGPoint(x: 512, y: 500)
let rayon: CGFloat = 250
let ballon = CGRect(x: centre.x - rayon, y: centre.y - rayon, width: 2 * rayon, height: 2 * rayon)

// Ombre portée sur la pelouse
ctx.saveGState()
ctx.addEllipse(in: CGRect(x: centre.x - 210, y: centre.y + rayon - 26, width: 420, height: 70))
ctx.setFillColor(couleur(0x0B3317, 0.45))
ctx.setShadow(offset: .zero, blur: 30, color: couleur(0x0B3317, 0.6))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 14), blur: 30, color: couleur(0x000000, 0.4))
ctx.addEllipse(in: ballon)
ctx.setFillColor(couleur(0xFFFFFF))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addEllipse(in: ballon)
ctx.clip()
ctx.drawRadialGradient(degrade([couleur(0xFFFFFF), couleur(0xE9ECF4), couleur(0xA9B0C2)], [0, 0.6, 1]),
                       startCenter: CGPoint(x: centre.x - 90, y: centre.y - 110), startRadius: 0,
                       endCenter: centre, endRadius: rayon * 1.05, options: [.drawsAfterEndLocation])

// Pentagone central (pointe en haut) et cinq pentagones vers ses sommets.
let noir = couleur(0x1E2233)
let angleCentral = -CGFloat.pi / 2
let central = pentagone(centre, rayon * 0.34, angleCentral)
var exterieurs: [[CGPoint]] = []
for k in 0..<5 {
    let a = angleCentral + CGFloat(k) * 2 * .pi / 5
    let c = CGPoint(x: centre.x + rayon * 0.98 * cos(a), y: centre.y + rayon * 0.98 * sin(a))
    exterieurs.append(pentagone(c, rayon * 0.36, a + .pi))
}

// Coutures : sommet central → pentagone extérieur, et entre pentagones voisins.
ctx.setStrokeColor(couleur(0x5A6175))
ctx.setLineWidth(9)
ctx.setLineCap(.round)
for k in 0..<5 {
    ctx.move(to: central[k])
    ctx.addLine(to: exterieurs[k][0])
    let suivant = exterieurs[(k + 1) % 5]
    ctx.move(to: exterieurs[k][4])
    ctx.addLine(to: suivant[1])
}
ctx.strokePath()

ctx.setFillColor(noir)
ctx.addPath(polygone(central))
for p in exterieurs { ctx.addPath(polygone(p)) }
ctx.fillPath()

// Reflet
ctx.drawRadialGradient(degrade([couleur(0xFFFFFF, 0.55), couleur(0xFFFFFF, 0)], [0, 1]),
                       startCenter: CGPoint(x: centre.x - 100, y: centre.y - 130), startRadius: 0,
                       endCenter: CGPoint(x: centre.x - 100, y: centre.y - 130), endRadius: 120, options: [])
ctx.restoreGState()

// Liseré du ballon
ctx.addEllipse(in: ballon)
ctx.setStrokeColor(couleur(0x1E2233, 0.25))
ctx.setLineWidth(4)
ctx.strokePath()

guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
do {
    try png.write(to: URL(fileURLWithPath: sortie))
    print("Icône écrite : \(sortie)")
} catch {
    FileHandle.standardError.write(Data("Écriture impossible : \(error.localizedDescription)\n".utf8))
    exit(1)
}
