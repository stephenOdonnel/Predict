//
//  StructureViewModel.swift
//  Predict
//  © 2026 Stephen O'Donnell, Tanguy Labbe · GNU GPL v3 ou ultérieure (fichier LICENSE).
//
//  Thème et composants d'interface partagés (repris de Finance et MedCompta, accent indigo).
//
import SwiftUI
import AppKit
import Foundation

struct DebugLog: Identifiable {
    enum LogLevel: String {
        case info = "INFO"
        case success = "OK"
        case warning = "WARN"
        case error = "ERR"
    }

    let id = UUID()
    let message: String
    let level: LogLevel
    let date: Date = Date()
}

// MARK: - Thème

/// Valeurs visuelles communes. Les teintes sont sémantiques et s'adaptent donc
/// au thème clair comme au thème sombre.
enum Theme {

    // Surfaces
    /// Fond d'une carte / d'un panneau.
    static let carte = Color(nsColor: .controlBackgroundColor)
    /// Fond d'un petit contrôle (menu déroulant, pastille de filtre).
    static let controle = Color.primary.opacity(0.07)
    /// Piste d'une barre de progression.
    static let piste = Color.primary.opacity(0.12)

    /// Couleur d'accent de l'application.
    static let accent = Color.indigo

    // Résultats : victoire / gain, nul, défaite / perte.
    static let gain = Color.green
    static let nul = Color.gray
    static let perte = Color.red

    // Typographie — quatre styles.
    static let titre = Font.title2.weight(.semibold)
    static let section = Font.headline
    static let corps = Font.callout
    static let legende = Font.caption

    // Rayons
    static let rayon: CGFloat = 12
    static let rayonPetit: CGFloat = 8

    // Échelle d'espacement
    static let espaceXS: CGFloat = 4
    static let espaceS: CGFloat = 8
    static let espaceM: CGFloat = 16
    static let espaceL: CGFloat = 24
}

// MARK: - Style Liquid Glass

/// Regroupe des éléments en verre pour qu'ils soient rendus ensemble
/// (macOS 26) ; sans effet avant.
struct ConteneurVerre<Contenu: View>: View {
    var espacement: CGFloat = 12
    @ViewBuilder let contenu: () -> Contenu

    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: espacement) { contenu() }
        } else {
            contenu()
        }
    }
}

/// Libellé d'un menu déroulant en verre liquide. `Menu` ignore
/// `.buttonStyle(.glass)` : le verre est donc porté par le libellé, et le
/// chevron est dessiné ici (celui du système est masqué par l'appelant).
struct LibelleMenuVerre: View {
    let texte: String

    var body: some View {
        // Un seul Text : dans un libellé de Menu, une HStack image + texte
        // était réordonnée avec le chevron devant.
        (Text(texte) + Text("  ")
            + Text(Image(systemName: "chevron.down"))
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary))
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .contentShape(Capsule())
        .verreCapsule()
    }
}

/// Filtre en menu de verre, titré au-dessus (Membre, Année, Catégorie…).
struct FiltreMenu<Valeur: Hashable>: View {
    let titre: String
    @Binding var selection: Valeur
    let options: [(valeur: Valeur, texte: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titre)
                .font(Theme.legende)
                .foregroundColor(.secondary)

            Menu {
                ForEach(options, id: \.valeur) { option in
                    Button(option.texte) { selection = option.valeur }
                }
            } label: {
                LibelleMenuVerre(texte: options.first { $0.valeur == selection }?.texte ?? "—")
            }
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }
}

extension View {
    /// Carte de contenu : fond uni à coins continus et liseré discret, comme
    /// les groupes des réglages système. Le verre est réservé aux commandes
    /// qui flottent au-dessus du contenu, pas au contenu lui-même.
    func carte(_ rayon: CGFloat = Theme.rayon, fond: Color = Theme.carte) -> some View {
        self
            .background(fond, in: RoundedRectangle(cornerRadius: rayon, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: rayon, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
            )
    }

    /// Verre liquide (macOS 26) ; matériau translucide avant.
    @ViewBuilder
    func verre(_ rayon: CGFloat = Theme.rayon) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: rayon))
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: rayon, style: .continuous))
        }
    }

    /// Capsule de verre réactive au survol et au clic (macOS 26) ; fond
    /// discret avant. Pour les libellés de menus déroulants.
    @ViewBuilder
    func verreCapsule() -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            self.background(Theme.controle, in: Capsule())
        }
    }

    /// Bouton en verre liquide ; bordé avant macOS 26.
    @ViewBuilder
    func boutonVerre() -> some View {
        if #available(macOS 26, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    /// Bouton d'action principale en verre teinté ; proéminent bordé avant.
    @ViewBuilder
    func boutonVerreProeminent() -> some View {
        if #available(macOS 26, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Dernière sauvegarde

/// Date et emplacement de la dernière sauvegarde réussie, par destination.
struct Sauvegarde: Codable, Equatable {
    var date: Date
    var chemin: String

    static func lire(_ cle: String) -> Sauvegarde? {
        guard let d = UserDefaults.standard.data(forKey: cle) else { return nil }
        return try? JSONDecoder().decode(Sauvegarde.self, from: d)
    }

    func ecrire(_ cle: String) {
        if let d = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(d, forKey: cle)
        }
    }

    /// "aujourd'hui à 14:32", "hier à 09:10", sinon date complète.
    var dateLisible: String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.unitsStyle = .full
        let h = DateFormatter()
        h.locale = Locale(identifier: "fr_FR")
        h.dateFormat = "dd/MM/yyyy HH:mm"
        return "\(h.string(from: date)) (\(f.localizedString(for: date, relativeTo: Date())))"
    }

    /// Chemin raccourci : ~/… plutôt que /Users/<nom>/…
    var cheminLisible: String {
        (chemin as NSString).abbreviatingWithTildeInPath
    }

    var existeEncore: Bool {
        FileManager.default.fileExists(atPath: chemin)
    }
}

// MARK: - Apparence (clair / sombre / système)
/// Préférence d'apparence, conservée entre deux lancements.
/// `.systeme` suit le réglage de macOS.
enum Apparence: String, CaseIterable, Identifiable {
    case systeme
    case clair
    case sombre

    static let cle = "apparence"

    var id: String { rawValue }

    var titre: String {
        switch self {
        case .systeme: return "Système"
        case .clair:   return "Clair"
        case .sombre:  return "Sombre"
        }
    }

    var icone: String {
        switch self {
        case .systeme: return "circle.lefthalf.filled"
        case .clair:   return "sun.max.fill"
        case .sombre:  return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .systeme: return nil
        case .clair:   return .light
        case .sombre:  return .dark
        }
    }

    /// Aligne aussi les éléments AppKit (barre de titre, NSOpenPanel, menus)
    /// que `preferredColorScheme` ne touche pas.
    func appliquerAAppKit() {
        switch self {
        case .systeme: NSApp?.appearance = nil
        case .clair:   NSApp?.appearance = NSAppearance(named: .aqua)
        case .sombre:  NSApp?.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

/// Sélecteur compact pour l'onglet Apparence.
struct ApparencePicker: View {
    @AppStorage(Apparence.cle) private var apparence: Apparence = .systeme

    var body: some View {
        Picker("Apparence", selection: $apparence) {
            ForEach(Apparence.allCases) { a in
                Label(a.titre, systemImage: a.icone).tag(a)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        // L'application à AppKit est faite par la racine (Ligue1App) sur le
        // même @AppStorage.
    }
}

// MARK: - Saisie numérique sécurisée
/// Ne garde que les chiffres et UN séparateur décimal ("," accepté comme au clavier français),
/// limite la longueur et refuse NaN / infini.
enum SaisieNumerique {

    /// Garde les chiffres et UN séparateur décimal, en conservant celui qui a été
    /// tapé : sur un clavier français la virgule est la touche naturelle.
    static func nettoyer(_ texte: String) -> String {
        var resultat = ""
        var separateurVu = false
        for c in texte {
            if c.isASCII, c.isNumber {
                resultat.append(c)
            } else if (c == "." || c == ","), !separateurVu {
                resultat.append(c)
                separateurVu = true
            }
        }
        return String(resultat.prefix(12))
    }

    /// Virgule et point sont acceptés indifféremment à la lecture.
    /// Un séparateur en fin de saisie ("12," pendant la frappe) ne bloque pas.
    static func valeur(_ texte: String) -> Double {
        var normalise = texte.replacingOccurrences(of: ",", with: ".")
        if normalise.hasSuffix(".") { normalise.removeLast() }
        if normalise.hasPrefix(".") { normalise = "0" + normalise }
        guard !normalise.isEmpty, let v = Double(normalise), v.isFinite else { return 0 }
        return v
    }
}

// MARK: - Formats

enum Format {
    static let fr = Locale(identifier: "fr_FR")

    static func euro(_ v: Double, decimales: Bool = false) -> String {
        v.formatted(.currency(code: "EUR").locale(fr)
            .precision(.fractionLength(decimales ? 2 : 0)))
    }

    static func pourcent(_ v: Double, decimales: Int = 1, fixe: Bool = false) -> String {
        (v / 100).formatted(.percent.locale(fr).precision(.fractionLength(fixe ? decimales...decimales : 0...decimales)))
    }

    /// Nombre à la française (virgule décimale), sans séparateur de milliers.
    static func nombre(_ v: Double, decimales: Int = 2, fixe: Bool = false) -> String {
        v.formatted(.number.locale(fr).grouping(.never)
            .precision(.fractionLength(fixe ? decimales...decimales : 0...decimales)))
    }

    /// Valeur signée : « +1,2 », « -0,4 ».
    static func signe(_ v: Double, decimales: Int = 1) -> String {
        (v >= 0 ? "+" : "") + nombre(v, decimales: decimales, fixe: true)
    }
}

// MARK: - Composants

/// Pastille d'état commune aux destinations de sauvegarde.
struct StatusBadge: View {
    let actif: Bool
    let texte: String
    var infobulle: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(actif ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            Text(texte)
                .font(Theme.legende)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Theme.controle, in: Capsule())
        .help(infobulle ?? texte)
    }
}

/// Confirme que la dernière écriture a réussi.
struct SauvegardeFeedbackVue: View {
    let resultatLocal: Bool?
    let sauvegardeLocale: Sauvegarde?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Dernière sauvegarde")
                .font(Theme.legende)
                .foregroundColor(.secondary)

            ligne(
                nom: "Local",
                resultat: resultatLocal,
                sauvegarde: sauvegardeLocale,
                absent: "jamais"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.espaceS)
        .background(Theme.controle, in: RoundedRectangle(cornerRadius: Theme.rayon, style: .continuous))
    }

    @ViewBuilder
    private func ligne(nom: String, resultat: Bool?, sauvegarde: Sauvegarde?, absent: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbole(resultat))
                .foregroundColor(couleur(resultat))
                .font(.caption)

            Text(nom)
                .font(Theme.legende)

            Spacer()

            Text(texte(resultat: resultat, sauvegarde: sauvegarde, absent: absent))
                .font(Theme.legende)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .help(sauvegarde.map { "\($0.dateLisible)\n\($0.cheminLisible)" } ?? absent)
    }

    private func symbole(_ resultat: Bool?) -> String {
        switch resultat {
        case true?: return "checkmark.circle.fill"
        case false?: return "exclamationmark.triangle.fill"
        case nil: return "minus.circle"
        }
    }

    private func couleur(_ resultat: Bool?) -> Color {
        switch resultat {
        case true?: return .green
        case false?: return .orange
        case nil: return .secondary
        }
    }

    private func texte(resultat: Bool?, sauvegarde: Sauvegarde?, absent: String) -> String {
        if resultat == false { return "échec" }
        guard let s = sauvegarde else { return absent }
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.unitsStyle = .abbreviated
        return f.localizedString(for: s.date, relativeTo: Date())
    }
}

/// Chiffre clé du tableau de bord : un intitulé, une valeur, un détail.
struct TuileChiffre: View {
    let titre: String
    let valeur: String
    var detail: String? = nil
    var icone: String
    var couleurValeur: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.espaceXS) {
            Label(titre, systemImage: icone)
                .font(Theme.legende)
                .foregroundColor(.secondary)
            Text(valeur)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundColor(couleurValeur)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let detail {
                Text(detail)
                    .font(Theme.legende)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(Theme.espaceM)
        .carte()
    }
}

/// État vide d'un tableau : dit s'il n'y a rien du tout ou si le filtre est trop restrictif.
struct EtatVide: View {
    let icone: String
    let titre: String
    let detail: String

    var body: some View {
        VStack(spacing: Theme.espaceS) {
            Image(systemName: icone)
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text(titre)
                .font(Theme.section)
            Text(detail)
                .font(Theme.legende)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding(Theme.espaceL)
    }
}

/// Bandeau d'avertissement orange, comme les échéances manquantes de MedCompta.
struct Bandeau: View {
    let titre: String
    let lignes: [String]
    var icone: String = "exclamationmark.triangle.fill"
    var couleur: Color = .orange

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.espaceXS) {
            Label(titre, systemImage: icone)
                .font(Theme.section)
                .foregroundColor(couleur)
            ForEach(lignes, id: \.self) { ligne in
                Text(ligne)
                    .font(Theme.legende)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.espaceS)
        .background(couleur.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: Theme.rayon, style: .continuous))
    }
}
