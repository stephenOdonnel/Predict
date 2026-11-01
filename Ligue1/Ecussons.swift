//
//  Ecussons.swift
//  Predict
//  © 2026 Stephen O'Donnell, Tanguy Labbe · GNU GPL v3 ou ultérieure (fichier LICENSE).
//
//  Écusson d'un club : le logo déposé par l'utilisateur dans le dossier
//  `logos/` des données s'il existe, sinon un blason bicolore aux couleurs du
//  club avec ses initiales (icons.py de l'app Python). Les vrais logos sont des
//  marques déposées : l'application n'en télécharge ni n'en fournit aucun.
//
import SwiftUI
import AppKit
import CryptoKit

enum Ecussons {
    /// Couleurs principale / secondaire (approximatives, purement esthétiques).
    static let couleurs: [String: (UInt32, UInt32)] = [
        "Paris Saint Germain": (0x04234C, 0xDA291C),
        "RC Lens": (0xC8102E, 0xFFD100),
        "Olympique de Marseille": (0x2FAEE0, 0xFFFFFF),
        "Stade Rennais FC": (0xE2001A, 0x111111),
        "LOSC": (0xC41230, 0x0033A0),
        "OGC Nice": (0xC8102E, 0x111111),
        "AS Monaco": (0xE2001A, 0xFFFFFF),
        "Stade Brestois": (0xE2001A, 0xFFFFFF),
        "Olympique Lyonnais": (0x0033A0, 0xE2001A),
        "FC Metz": (0x7A1F3D, 0x8EC6E5),
        "Toulouse FC": (0x4B0E2E, 0x7B2D5E),
        "RC Strasbourg": (0x0060A9, 0xFFFFFF),
        "Angers SCO": (0x111111, 0xFFFFFF),
        "FC Lorient": (0xF58220, 0x111111),
        "AJ Auxerre": (0x003DA5, 0xFFFFFF),
        "Paris FC": (0x003DA5, 0xC8102E),
        "FC Nantes": (0xFFD100, 0x1F7A3F),
        "Le Havre": (0x0072CE, 0xFFFFFF)
    ]

    static let initialesConnues: [String: String] = [
        "Paris Saint Germain": "PSG", "RC Lens": "RCL", "Olympique de Marseille": "OM",
        "Stade Rennais FC": "SRFC", "LOSC": "LOSC", "OGC Nice": "OGCN", "AS Monaco": "ASM",
        "Stade Brestois": "SB29", "Olympique Lyonnais": "OL", "FC Metz": "FCM", "Toulouse FC": "TFC",
        "RC Strasbourg": "RCS", "Angers SCO": "SCO", "FC Lorient": "FCL", "AJ Auxerre": "AJA",
        "Paris FC": "PFC", "FC Nantes": "FCN", "Le Havre": "HAC"
    ]

    static func initiales(_ nom: String) -> String {
        initialesConnues[nom]
            ?? String(nom.split(separator: " ").prefix(3).compactMap(\.first)).uppercased()
    }

    /// Club inconnu : teinte stable tirée du nom (MD5), éclaircie.
    static func couleursClub(_ nom: String) -> (Color, Color) {
        if let (a, b) = couleurs[nom] { return (couleur(a), couleur(b)) }
        let h = Array(Insecure.MD5.hash(data: Data(nom.utf8)))
        let r = min(255, 60 + Int(h[0])), g = min(255, 60 + Int(h[1])), b = min(255, 60 + Int(h[2]))
        return (couleur(UInt32(r << 16 | g << 8 | b)), .white)
    }

    static func couleur(_ hex: UInt32) -> Color {
        Color(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
              blue: Double(hex & 0xFF) / 255, opacity: 1)
    }

    /// Nom de fichier attendu dans `logos/` : espaces remplacés par « _ ».
    static func nomFichier(_ equipe: String) -> String {
        equipe.replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "/", with: "_") + ".png"
    }
}

/// Silhouette de blason : coins supérieurs biseautés, pointe en bas.
struct FormeBlason: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height, biseau = w * 0.05
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x, y: r.minY + y) }
        var p = Path()
        p.move(to: pt(w * 0.06 + biseau, h * 0.08))
        p.addLine(to: pt(w * 0.94 - biseau, h * 0.08))
        p.addLine(to: pt(w * 0.94, h * 0.08 + biseau))
        p.addLine(to: pt(w * 0.94, h * 0.52))
        p.addLine(to: pt(w * 0.50, h * 0.97))
        p.addLine(to: pt(w * 0.06, h * 0.52))
        p.addLine(to: pt(w * 0.06, h * 0.08 + biseau))
        p.closeSubpath()
        return p
    }
}

struct Ecusson: View {
    @EnvironmentObject var vm: Ligue1ViewModel
    let equipe: String
    var taille: CGFloat = 24

    var body: some View {
        Group {
            if let image = vm.logos[equipe] {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                blason
            }
        }
        .frame(width: taille, height: taille)
        .accessibilityHidden(true)
    }

    private var blason: some View {
        let (principale, secondaire) = Ecussons.couleursClub(equipe)
        let texte = Ecussons.initiales(equipe)
        return ZStack(alignment: .top) {
            HStack(spacing: 0) {
                principale
                secondaire
            }
            .clipShape(FormeBlason())
            FormeBlason()
                .stroke(Color.white.opacity(0.63), lineWidth: max(1, taille / 40))
            Text(texte)
                .font(.system(size: taille * (texte.count <= 3 ? 0.28 : 0.22), weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.7), radius: 0.6)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: taille * 0.86, height: taille * 0.46)
        }
    }
}

/// Écusson et nom du club, alignés.
struct EtiquetteEquipe: View {
    let equipe: String
    var taille: CGFloat = 22
    /// Nom à gauche de l'écusson (équipe à l'extérieur d'une carte de match).
    var inverse = false

    var body: some View {
        HStack(spacing: Theme.espaceS) {
            if inverse {
                Text(equipe).lineLimit(1)
                Ecusson(equipe: equipe, taille: taille)
            } else {
                Ecusson(equipe: equipe, taille: taille)
                Text(equipe).lineLimit(1)
            }
        }
    }
}
