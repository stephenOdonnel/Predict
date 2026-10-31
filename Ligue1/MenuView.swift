//
//  MenuView.swift
//  Ligue1
//  © 2026 Stephen O'Donnell, Tanguy Labbe · GNU GPL v3 ou ultérieure (fichier LICENSE).
//
import SwiftUI
import AppKit

// MARK: Sidebar menu item
struct MenuItem: Identifiable {
    let id: String
    let title: String
    let icon: String
    let detail: String

    /// Sections de la barre latérale, dans l'ordre d'affichage.
    static let toutes: [MenuItem] = [
        MenuItem(id: "tableau", title: "Tableau de bord", icon: "chart.bar.xaxis",
                 detail: "Prochaine journée, conseils, classement"),
        MenuItem(id: "journees", title: "Journées & cotes", icon: "sportscourt",
                 detail: "Scores, xG, minutes de but, cotes"),
        MenuItem(id: "classements", title: "Classements", icon: "list.number",
                 detail: "Général, domicile, top 9, xPoints"),
        MenuItem(id: "equipe", title: "Analyse équipe", icon: "shield.lefthalf.filled",
                 detail: "Forme, rang, bilans, calendrier"),
        MenuItem(id: "paris", title: "Simulation des paris", icon: "eurosign.circle",
                 detail: "Value bets, bankrolls, Kelly"),
        MenuItem(id: "conseils", title: "Conseils de paris", icon: "lightbulb",
                 detail: "Matchs à venir, probabilité, précision"),
        MenuItem(id: "probabilites", title: "Probabilités finales", icon: "square.grid.3x3.fill",
                 detail: "Monte Carlo du classement final"),
        MenuItem(id: "backtest", title: "Backtest", icon: "checkmark.seal",
                 detail: "Précision du modèle face aux cotes")
    ]

    /// Le tableau de bord reste toujours affiché : c'est la section de repli.
    static let obligatoire = "tableau"

    /// Sections masquées (Paramètres › Apparence), identifiants séparés par des virgules.
    static let cleMasquees = "sectionsMasquees"

    static func masquees(_ stockage: String) -> Set<String> {
        Set(stockage.split(separator: ",").map(String.init)).subtracting([obligatoire])
    }

    static func visibles(_ stockage: String) -> [MenuItem] {
        let cachees = masquees(stockage)
        return toutes.filter { !cachees.contains($0.id) }
    }
}

struct MenuView: View {

    @Environment(\.openSettings) private var openSettings

    // MARK: Menu items
    @AppStorage(MenuItem.cleMasquees) private var sectionsMasquees = ""

    private var menuItems: [MenuItem] { MenuItem.visibles(sectionsMasquees) }

    // MARK: Selected menu item
    @State private var selectedID: String? = MenuItem.obligatoire

    @EnvironmentObject var vm: Ligue1ViewModel

    var body: some View {
        // NavigationSplitView fournit la barre latérale native : verre liquide
        // sur macOS 26, bouton de repli, barre d'outils unifiée. Le chargement
        // passe par `.task`, hors du cycle de mise à jour de la vue.
        NavigationSplitView {
            barreLaterale
                .navigationSplitViewColumnWidth(min: 250, ideal: 290, max: 380)
        } detail: {
            detail
        }
        .task {
            vm.chargerDonnees()
        }
        .sheet(item: Binding(
            get: { vm.alerteIntegrite },
            set: { if $0 == nil { vm.alerteIntegrite = nil } }
        )) { alerte in
            RevueIntegriteView(alerte: alerte)
                .environmentObject(vm)
        }
    }

    // MARK: Barre latérale

    /// Liste puis pied dans une pile, et non `safeAreaInset` : l'inset était
    /// mesuré à largeur nulle pendant la mise en place de la colonne.
    private var barreLaterale: some View {
        VStack(spacing: 0) {
            liste
            piedBarreLaterale
        }
    }

    private var liste: some View {
        List(selection: $selectedID) {
            // Même source que l'écran de connexion : l'icône du bundle.
            HStack(spacing: Theme.espaceS) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)

                SignatureLigue1()
                    .frame(height: 34)
            }
            .padding(.vertical, Theme.espaceXS)
            .selectionDisabled(true)

            // Menu items — List native : survol, teinte d'accent du système,
            // navigation au clavier.
            Section {
                ForEach(menuItems) { item in
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                            Text(item.detail)
                                .font(Theme.legende)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: item.icon)
                    }
                    .padding(.vertical, 2)
                    .tag(item.id)
                }
            }

            if !vm.ligue.matches.isEmpty {
                Section("Saison") {
                    let joues = vm.ligue.matchsJoues.count
                    Label("\(joues) / \(vm.ligue.matches.count) matchs joués", systemImage: "soccerball")
                    if let leader = Classements.general(vm.ligue).first, joues > 0 {
                        Label {
                            Text("\(leader.equipe) · \(leader.points) pts")
                        } icon: {
                            Ecusson(equipe: leader.equipe, taille: 16)
                        }
                    }
                }
                .font(Theme.corps)
                .foregroundColor(.secondary)
                .selectionDisabled(true)
            }
        }
        .listStyle(.sidebar)
        .onChange(of: sectionsMasquees) { _, nouveau in
            if let id = selectedID, MenuItem.masquees(nouveau).contains(id) { selectedID = MenuItem.obligatoire }
        }
    }

    /// Pied de la barre latérale : paramètres et état des sauvegardes.
    private var piedBarreLaterale: some View {
        VStack(spacing: Theme.espaceS) {
            Button {
                openSettings()
            } label: {
                Label("Paramètres", systemImage: "gearshape.fill")
            }
            .keyboardShortcut(",", modifiers: .command)
            .buttonStyle(.bordered)

            if let erreur = vm.derniereErreur {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    // Hauteur bornée : à largeur nulle, un texte libre explosait.
                    Text(erreur)
                        .font(Theme.legende)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .help(erreur)
                    Spacer()
                    Button {
                        vm.derniereErreur = nil
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(8)
                .background(Color.orange.opacity(0.15),
                            in: RoundedRectangle(cornerRadius: Theme.rayonPetit, style: .continuous))
            }

            if let blocage = vm.blocageIntegrite {
                VStack(alignment: .leading, spacing: Theme.espaceXS) {
                    Label("Saisie bloquée", systemImage: "lock.trianglebadge.exclamationmark.fill")
                        .font(Theme.legende)
                        .foregroundColor(.orange)
                    Text("\(blocage.fichier) a été modifié en dehors de l'application. "
                         + "Rien n'y est enregistré tant que ce n'est pas réglé.")
                        .font(Theme.legende)
                        .foregroundColor(.secondary)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Régler…") { vm.revoirIntegrite() }
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.espaceS)
                .background(Color.orange.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: Theme.rayon, style: .continuous))
            }

            SauvegardeFeedbackVue(
                resultatLocal: vm.dernierResultatLocal,
                sauvegardeLocale: vm.derniereSauvegardeLocale
            )
        }
        .padding(Theme.espaceM)
    }

    // MARK: Contenu

    private var titreSection: String {
        menuItems.first { $0.id == selectedID }?.title ?? "Ligue 1"
    }

    private var detail: some View {
        Group {
            if !vm.saisonDisponible {
                BienvenueView()
            } else {
                switch selectedID {
                case "journees":     JourneesView()
                case "classements":  ClassementsView()
                case "equipe":       AnalyseEquipeView()
                case "paris":        ParisView()
                case "conseils":     ConseilsView()
                case "probabilites": ProbabilitesView()
                case "backtest":     BacktestView()
                default:             TableauDeBordView(selection: $selectedID)
                }
            }
        }
        .environmentObject(vm)
        .frame(minWidth: 760, maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(titreSection)
        .toolbar {
            // Un seul élément, toujours présent : le pont SwiftUI → NSToolbar
            // n'a ainsi jamais à recréer ses éléments en cours de layout.
            ToolbarItem(placement: .navigation) {
                boutonRecalcul
            }
        }
    }

    /// Relance le Monte Carlo du classement final (aussi relancé à chaque score validé).
    private var boutonRecalcul: some View {
        Button {
            vm.lancerSimulation()
        } label: {
            if vm.simulationEnCours {
                Label("Calcul en cours…", systemImage: "hourglass")
            } else {
                Label("Recalculer le classement final", systemImage: "arrow.triangle.2.circlepath")
            }
        }
        .disabled(vm.simulationEnCours || vm.modele == nil)
        .keyboardShortcut("r", modifiers: .command)
        .help(vm.simulationEnCours
              ? "Monte Carlo en cours (\(vm.reglages.simulations) saisons)"
              : "Recalculer le classement final : \(vm.reglages.simulations) saisons simulées (⌘R)")
    }
}

/// Premier lancement : aucune saison venue des CSV dans le dossier de données.
struct BienvenueView: View {
    @EnvironmentObject var vm: Ligue1ViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.espaceM) {
            Label("Bienvenue dans Ligue1", systemImage: "hand.wave.fill")
                .font(Theme.titre)
            Text("Toutes les données viennent des CSV gratuits de football-data.co.uk : scores et cotes de la saison "
                 + "en cours, et les 10 saisons précédentes pour calibrer le modèle. Ils se téléchargent à l'ouverture "
                 + "de cet écran ; vous pouvez aussi les importer vous-même.")
                .font(Theme.corps)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            EtapesCSV()
            BoutonImportCSV(proeminent: true, automatique: true)
            if !vm.ligue.teams.isEmpty {
                Label("Le dossier de données contient une saison d'un ancien format : elle n'est pas utilisée et sera "
                      + "remplacée à l'import.", systemImage: "info.circle")
                    .font(Theme.legende)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .frame(maxWidth: 680, alignment: .leading)
        .padding(Theme.espaceL)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Où trouver les CSV et comment les importer.
struct EtapesCSV: View {
    private static let etapes = [
        "« Mettre à jour en ligne » télécharge sur football-data.co.uk le F1.csv de la saison en cours, ceux des 10 "
            + "saisons précédentes qui manquent et fixtures.csv (matchs de la semaine avec leurs cotes), puis les importe. "
            + "Au premier lancement, c'est automatique. Avec une clé The Odds API (Paramètres › Saison), il "
            + "télécharge aussi les cotes Winamax, Unibet et Betclic des matchs à venir.",
        "La saison de chaque fichier est lue dans ses dates : la plus récente devient la saison en cours, les autres "
            + "forment l'historique, sur lequel le modèle est calibré.",
        "Chaque semaine, « Mettre à jour en ligne » de nouveau : scores, cotes de référence et cotes moyennes se mettent "
            + "à jour, vos saisies sont gardées.",
        "Sans réseau : téléchargez « Le Championnat » (F1.csv) sur la page France (lien ci-dessous) et fixtures.csv, puis "
            + "« Importer des CSV… » en les sélectionnant tous (⌘A)."
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.espaceXS) {
            ForEach(Array(Self.etapes.enumerated()), id: \.offset) { i, etape in
                HStack(alignment: .top, spacing: 6) {
                    Text("\(i + 1).").monospacedDigit()
                    Text(etape).fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("L'application ne se connecte à internet que pour ces téléchargements, sur football-data.co.uk ; rien "
                 + "n'est envoyé. Cotes de pari : celles de Winamax, Unibet, Bwin et Betclic si vous les saisissez, sinon "
                 + "la cote moyenne en ligne du CSV, indicative. La cote de clôture Pinnacle ne sert qu'au modèle.")
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(Theme.legende)
    }
}

/// Choix des CSV (ou téléchargement de la mise à jour), confirmation si la saison
/// en cours est remplacée, puis import en arrière-plan (calibration comprise)
/// avec sa progression.
struct BoutonImportCSV: View {
    @EnvironmentObject var vm: Ligue1ViewModel
    var proeminent = false
    /// Lance la mise à jour en ligne à l'apparition, une fois par session.
    var automatique = false
    @State private var aImporter: Ligue1ViewModel.ImportCSV?
    @State private var statut: (texte: String, ok: Bool)?
    /// Import venu de « Mettre à jour en ligne » : suivi des cotes Winamax, Unibet, Betclic.
    @State private var enLigne = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.espaceS) {
            HStack(spacing: Theme.espaceM) {
                bouton
                    .disabled(occupe)
                Button {
                    telecharger()
                } label: {
                    Label(vm.telechargementEnCours ? "Téléchargement…" : "Mettre à jour en ligne",
                          systemImage: "arrow.down.circle")
                }
                .disabled(occupe)
                .help("Télécharge sur football-data.co.uk fixtures.csv, le F1.csv de la saison en cours et ceux des "
                      + "saisons passées manquantes, puis les importe.")
                if vm.telechargementEnCours {
                    ProgressView().controlSize(.small)
                }
                if vm.importEnCours {
                    if vm.calibrationEnCours {
                        ProgressView(value: vm.progressionCalibration)
                            .frame(width: 120)
                        Text("Calibration du modèle…")
                    } else {
                        ProgressView().controlSize(.small)
                        Text("Import…")
                    }
                }
            }
            .font(Theme.corps)
            Link(destination: FootballData.page) {
                Label("Ouvrir football-data.co.uk (saisons passées)", systemImage: "safari")
            }
            .font(Theme.corps)
            if let statut {
                Label(statut.texte, systemImage: statut.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(Theme.legende)
                    .foregroundColor(statut.ok ? .green : .orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            guard automatique, !vm.miseAJourAutomatiqueFaite, !occupe else { return }
            vm.miseAJourAutomatiqueFaite = true
            telecharger()
        }
        .confirmationDialog("Remplacer la saison en cours ?",
                            isPresented: Binding(get: { aImporter != nil }, set: { if !$0 { aImporter = nil } }),
                            presenting: aImporter) { i in
            Button("Importer et remplacer", role: .destructive) { lancer(i) }
            Button("Annuler", role: .cancel) { aImporter = nil }
        } message: { i in
            Text(avertissement(i))
        }
    }

    @ViewBuilder
    private var bouton: some View {
        let b = Button {
            choisir()
        } label: {
            Label("Importer des CSV…", systemImage: "tablecells")
        }
        if proeminent { b.boutonVerreProeminent() } else { b }
    }

    private var occupe: Bool {
        vm.importEnCours || vm.calibrationEnCours || vm.telechargementEnCours || vm.cotesEnCours
            || vm.blocageIntegrite != nil
    }

    private func telecharger() {
        statut = nil
        enLigne = true
        vm.telechargerMiseAJour { traiter($0) }
    }

    private func choisir() {
        guard let i = vm.lireCSV() else { return }
        enLigne = false
        traiter(i)
    }

    private func traiter(_ i: Ligue1ViewModel.ImportCSV) {
        guard !i.fichiers.isEmpty else {
            statut = (i.erreurs.isEmpty ? "Aucun fichier lisible." : i.resume, false)
            return
        }
        if i.remplaceSaison { aImporter = i } else { lancer(i) }
    }

    private func lancer(_ i: Ligue1ViewModel.ImportCSV) {
        aImporter = nil
        statut = nil
        vm.importerCSV(i) { erreur in
            if let erreur { statut = ([erreur, i.resume].joined(separator: "\n"), false) }
            else { statut = ("Import terminé.\n" + i.resume, i.erreurs.isEmpty) }
            guard enLigne, erreur == nil, vm.cotesEnLigneConfigurees else { return }
            vm.telechargerCotes { texte, ok in
                statut = ([statut?.texte, texte].compactMap { $0 }.joined(separator: "\n"), (statut?.ok ?? true) && ok)
            }
        }
    }

    private func avertissement(_ i: Ligue1ViewModel.ImportCSV) -> String {
        let actuelle = vm.saisonDisponible ? "La saison \(vm.ligue.season ?? "")" : "La saison enregistrée (ancien format)"
        return "\(actuelle) est remplacée par \(i.saisonCourante ?? "") : cotes saisies, xG, minutes, probabilités "
            + "figées, dépôts/retraits et paris forcés ou exclus sont effacés"
            + (vm.saisonDisponible ? " ; ses matchs joués rejoignent l'historique." : ", les réglages des paris remis à zéro.")
            + "\n\n" + i.resume
    }
}

/// « Ligue 1 » écrit d'un seul trait, à la manière du « hello » du premier
/// Macintosh, et tracé à l'apparition.
struct SignatureLigue1: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progression: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            TraitSignature()
                .trim(from: 0, to: progression)
                .stroke(LinearGradient(colors: [.mint, Theme.accent, .blue],
                                       startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(
                    lineWidth: geo.size.height * TraitSignature.epaisseur,
                    lineCap: .round, lineJoin: .round))
        }
        .aspectRatio(TraitSignature.cadre.width / TraitSignature.cadre.height, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Ligue 1")
        .onAppear {
            guard progression == 0 else { return }
            if reduceMotion {
                progression = 1
            } else {
                withAnimation(.easeInOut(duration: 2.5)) { progression = 1 }
            }
        }
    }
}

private struct TraitSignature: Shape {
    /// Coordonnées du tracé (commandes SVG absolues M/L/C) ; la boucle du g
    /// descend sous la ligne de base.
    static let cadre = CGRect(x: 30, y: 30, width: 510, height: 245)
    /// Épaisseur relative à la hauteur, comme le trait du « hello ».
    static let epaisseur: CGFloat = 13 / 245

    // L (boucle haute, hampe, boucle basse), i, g, u, e d'un trait, puis le 1, puis le point du i.
    private static let donnees = """
    M 92 128 C 104 98 126 58 150 46 C 166 38 174 52 160 66
    C 142 84 122 130 108 170 C 100 192 86 210 66 206 C 50 202 54 186 72 186
    C 96 186 120 204 150 198 C 165 194 172 160 176 142 C 176 165 172 190 180 198
    C 186 204 200 200 210 188 C 222 172 238 150 262 146 C 240 136 216 152 218 174
    C 220 196 248 196 258 172 C 262 160 264 150 266 142 C 264 190 262 230 248 255
    C 238 270 218 262 224 245 C 232 225 262 210 284 196
    C 294 185 298 160 302 142 C 300 165 296 195 314 198 C 330 200 338 170 342 142
    C 340 165 338 192 352 198 C 364 200 384 185 392 170 C 400 155 392 138 380 142
    C 364 148 362 190 384 198 C 396 202 410 196 422 186
    M 470 140 C 484 128 500 112 512 96 C 506 130 498 168 490 202
    M 172 112 L 173 111
    """

    func path(in rect: CGRect) -> Path {
        let c = Self.cadre
        let echelle = min(rect.width / c.width, rect.height / c.height)
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + (x - c.minX) * echelle,
                    y: rect.minY + (y - c.minY) * echelle)
        }

        var path = Path()
        var jetons = Self.donnees.split(whereSeparator: \.isWhitespace)[...]
        func n() -> CGFloat { CGFloat(Double(jetons.popFirst() ?? "") ?? 0) }
        while let commande = jetons.popFirst() {
            switch commande {
            case "M": path.move(to: pt(n(), n()))
            case "L": path.addLine(to: pt(n(), n()))
            case "C":
                let c1 = pt(n(), n()), c2 = pt(n(), n())
                path.addCurve(to: pt(n(), n()), control1: c1, control2: c2)
            default: break
            }
        }
        return path
    }
}

/// Montre ce que le fichier contient réellement avant de laisser l'utilisateur
/// trancher, ligne par ligne.
struct RevueIntegriteView: View {
    let alerte: AlerteIntegrite
    @EnvironmentObject var vm: Ligue1ViewModel
    @Environment(\.dismiss) private var dismiss

    /// Décision par enregistrement. Absent = gardé : par défaut, appliquer
    /// revient à accepter le fichier tel quel.
    @State private var garder: [String: Bool] = [:]

    private var resultat: ResultatComparaison { vm.differences(alerte) }

    var body: some View {
        let r = resultat

        VStack(alignment: .leading, spacing: Theme.espaceM) {
            Label("\(alerte.fichier) a été modifié en dehors de Ligue1",
                  systemImage: "exclamationmark.shield.fill")
                .font(Theme.titre)
                .foregroundColor(.orange)

            Text(alerte.sceauAbsent
                 ? "Son sceau d'intégrité a disparu : le fichier a peut-être été remplacé."
                 : "Son contenu ne correspond plus au sceau produit par l'application.")
                .font(Theme.legende)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            if let erreur = r.erreur {
                Label(erreur, systemImage: "xmark.octagon.fill")
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else if r.lignes.isEmpty {
                Text("Aucune différence de contenu : seul le sceau est en cause.")
                    .foregroundColor(.secondary)
            } else if r.lignes.contains(where: { $0.etat == .presente }) {
                // Pas de référence exploitable : on montre le fichier tel quel.
                contenu(r)
            } else {
                HStack {
                    Text("\(r.lignes.count) modification\(r.lignes.count > 1 ? "s" : "") détectée\(r.lignes.count > 1 ? "s" : "") — cochez celles à garder :")
                        .font(Theme.section)
                    Spacer()
                    Button("Tout garder") { tout(r, true) }
                        .buttonStyle(.link)
                    Button("Tout rejeter") { tout(r, false) }
                        .buttonStyle(.link)
                }
                contenu(r)
            }

            if r.inchangees > 0 {
                Text("\(r.inchangees) ligne\(r.inchangees > 1 ? "s" : "") inchangée\(r.inchangees > 1 ? "s" : "").")
                    .font(Theme.legende)
                    .foregroundColor(.secondary)
            }

            Divider()
            boutons(r)
        }
        .padding(Theme.espaceL)
        .frame(width: 660)
    }

    /// Seules les lignes qui diffèrent sont listées ; les identiques se
    /// résument à un compteur.
    @ViewBuilder
    private func contenu(_ r: ResultatComparaison) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.espaceS) {
                ForEach(r.lignes) { ligne in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(ligne.etat.rawValue)
                                .font(Theme.legende)
                                .foregroundColor(couleur(ligne.etat))

                            Spacer()

                            Toggle(ligne.intitule, isOn: Binding(
                                get: { garder[ligne.id] ?? true },
                                set: { garder[ligne.id] = $0 }
                            ))
                            .toggleStyle(.checkbox)
                            .font(Theme.legende)
                        }

                        if let avant = ligne.avant {
                            Text(avant)
                                .font(Theme.legende)
                                .foregroundColor(.secondary)
                                .strikethrough(ligne.etat == .modifiee)
                                .textSelection(.enabled)
                        }
                        if let apres = ligne.apres {
                            Text(apres)
                                .font(Theme.legende)
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.espaceS)
                    .background(couleur(ligne.etat).opacity(0.10),
                                in: RoundedRectangle(cornerRadius: Theme.rayonPetit, style: .continuous))
                }
            }
        }
        .frame(minHeight: 160, maxHeight: 280)
    }

    /// Texte et boutons sur deux lignes : côte à côte, les trois boutons
    /// débordaient de la feuille.
    @ViewBuilder
    private func boutons(_ r: ResultatComparaison) -> some View {
        VStack(alignment: .leading, spacing: Theme.espaceS) {
            Text("Appliquer réécrit le fichier selon vos choix : les lignes cochées "
                 + "gardent la valeur du fichier, les autres retrouvent la valeur "
                 + "d'avant. Refuser ne touche à rien et laisse la saisie bloquée.")
                .font(Theme.legende)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.espaceS) {
                Button("Refuser") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                if vm.versionScelleeDisponible(alerte) {
                    Button("Restaurer la version scellée") {
                        vm.restaurerVersionScellee(alerte)
                        dismiss()
                    }
                    .help("Réécrit le fichier avec son dernier contenu validé par l'application")
                }

                Spacer()

                Button("Appliquer") {
                    vm.appliquer(alerte, garder: garder)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(r.erreur != nil)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func tout(_ r: ResultatComparaison, _ valeur: Bool) {
        for ligne in r.lignes { garder[ligne.id] = valeur }
    }

    private func couleur(_ etat: LigneComparaison.Etat) -> Color {
        switch etat {
        case .ajoutee:   return .green
        case .supprimee: return .red
        case .modifiee:  return .orange
        case .presente:  return .blue
        }
    }
}
