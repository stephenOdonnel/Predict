//
//  JourneesView.swift
//  Predict
//  © 2026 Stephen O'Donnell, Tanguy Labbe · GNU GPL v3 ou ultérieure (fichier LICENSE).
//
//  Journées & cotes : une carte par match (date, score, forfait, xG, minutes de
//  but, probabilités, cotes de référence du CSV, cotes des quatre bookmakers).
//
import SwiftUI

struct JourneesView: View {
    @EnvironmentObject var vm: Ligue1ViewModel

    /// nil = première journée qui reste à jouer (la dernière si tout est joué).
    @State private var choix: Int?

    private var journee: Int {
        choix ?? vm.ligue.matchsAJouer.map(\.journee).min() ?? vm.ligue.nJournees
    }

    var body: some View {
        let matchs = vm.ligue.matchs(journee: journee)
        let joues = matchs.filter(\.joue).count

        ScrollView {
            VStack(alignment: .leading, spacing: Theme.espaceL) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Journée \(journee)")
                            .font(Theme.titre)
                        Text("\(joues) match\(joues > 1 ? "s" : "") joué\(joues > 1 ? "s" : "") sur \(matchs.count) · "
                             + "\(vm.ligue.matchsJoues.count) sur \(vm.ligue.matches.count) dans la saison")
                            .font(Theme.legende)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    ConteneurVerre {
                        HStack(alignment: .bottom, spacing: Theme.espaceS) {
                            Button {
                                choix = max(journee - 1, 1)
                            } label: {
                                Image(systemName: "chevron.left")
                            }
                            .boutonVerre()
                            .disabled(journee <= 1)
                            .help("Journée précédente")

                            FiltreMenu(titre: "Journée", selection: Binding(get: { journee }, set: { choix = $0 }),
                                       options: (1...max(vm.ligue.nJournees, 1)).map { ($0, "J\($0)") })

                            Button {
                                choix = min(journee + 1, vm.ligue.nJournees)
                            } label: {
                                Image(systemName: "chevron.right")
                            }
                            .boutonVerre()
                            .disabled(journee >= vm.ligue.nJournees)
                            .help("Journée suivante")
                        }
                    }
                }

                if !vm.peutModifier(.ligue) {
                    Bandeau(titre: "Saisie bloquée",
                            lignes: ["\(FichierDonnees.ligue.nom) n'a pas pu être chargé ou a été modifié en dehors de "
                                     + "l'application : rien n'y sera enregistré tant que ce n'est pas réglé."])
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 540), spacing: Theme.espaceM, alignment: .top)],
                          alignment: .leading, spacing: Theme.espaceM) {
                    ForEach(matchs) { m in
                        CarteMatch(match: m)
                            // Rechargement (import, revue d'intégrité) : les champs repartent des données.
                            .id("\(m.id)#\(vm.versionDonnees)")
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Carte d'un match

/// - Match à jouer : probabilités du modèle en direct, ou des xG saisis s'ils sont renseignés.
/// - Match joué : probabilités PRÉ-MATCH figées (jamais recalculées), plus les
///   probabilités après-match tirées du xG réel s'il est connu.
/// Les cotes restent modifiables dans les deux cas.
struct CarteMatch: View {
    @EnvironmentObject var vm: Ligue1ViewModel
    let match: Match

    @State private var butsDomicile: String
    @State private var butsExterieur: String
    @State private var xgDomicile: String
    @State private var xgExterieur: String
    @State private var minutesDomicile: String
    @State private var minutesExterieur: String
    @State private var cotes: [Bookmaker: [String]]
    @State private var cotesDepliees: Bool
    @State private var statut: (texte: String, couleur: Color)?
    @State private var statutMinutes: (texte: String, couleur: Color)?

    init(match m: Match) {
        match = m
        _butsDomicile = State(initialValue: m.butsDomicile.map(String.init) ?? "")
        _butsExterieur = State(initialValue: m.butsExterieur.map(String.init) ?? "")
        _xgDomicile = State(initialValue: m.xgDomicile.map { Format.nombre($0) } ?? "")
        _xgExterieur = State(initialValue: m.xgExterieur.map { Format.nombre($0) } ?? "")
        _minutesDomicile = State(initialValue: (m.minutesDomicile ?? []).joined(separator: ", "))
        _minutesExterieur = State(initialValue: (m.minutesExterieur ?? []).joined(separator: ", "))
        var textes: [Bookmaker: [String]] = [:]
        for b in Bookmaker.allCases {
            textes[b] = (0..<3).map { i in m.cotes[b].flatMap { $0.count == 3 ? Format.nombre($0[i]) : nil } ?? "" }
        }
        _cotes = State(initialValue: textes)
        // Repliées par défaut, sauf si au moins un bookmaker est déjà renseigné.
        _cotesDepliees = State(initialValue: !m.livres.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.espaceS + 2) {
            if let infos = dateEtReference {
                Text(infos)
                    .font(Theme.legende)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            enTete
            actionsScore
            ligneXg
            ligneMinutes
            probabilites
            sectionCotes
        }
        .padding(Theme.espaceM)
        .carte()
        .disabled(!vm.peutModifier(.ligue))
    }

    // MARK: Score

    /// « sam. 16 août 2025 · réf. 1,85 / 3,6 / 4,2 · moy. en ligne … » ; sans date, « date à fixer ».
    private var dateEtReference: String? {
        var parties: [String] = []
        if let d = match.date.flatMap(Jour.depuisISO) {
            parties.append(Jour.versDate(d).formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year()
                .locale(Format.fr)))
        } else if !match.joue {
            parties.append("date à fixer")
        }
        if let r = match.cotesReference {
            parties.append("réf. " + r.map { Format.nombre($0) }.joined(separator: " / "))
        }
        if let r = match.cotesMoyennes {
            parties.append("moy. en ligne " + r.map { Format.nombre($0) }.joined(separator: " / "))
        }
        return parties.isEmpty ? nil : parties.joined(separator: " · ")
    }

    private var enTete: some View {
        HStack(spacing: Theme.espaceS) {
            EtiquetteEquipe(equipe: match.domicile, taille: 32)
                .font(Theme.section)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                champScore($butsDomicile)
                Text("–").font(Theme.section)
                champScore($butsExterieur)
            }

            EtiquetteEquipe(equipe: match.exterieur, taille: 32, inverse: true)
                .font(Theme.section)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func champScore(_ texte: Binding<String>) -> some View {
        TextField("", text: texte)
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.center)
            .font(.title3.weight(.semibold).monospacedDigit())
            .frame(width: 44)
            .onChange(of: texte.wrappedValue) { _, nouveau in
                let filtre = String(nouveau.filter(\.isNumber).prefix(2))
                if filtre != nouveau { texte.wrappedValue = filtre }
            }
            .onSubmit(validerScore)
    }

    private var actionsScore: some View {
        HStack(spacing: Theme.espaceS) {
            Button("Valider le score", action: validerScore)
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .controlSize(.small)
            Button("Effacer") {
                butsDomicile = ""
                butsExterieur = ""
                if let e = vm.effacerScore(match.id) { statut = (e, Theme.perte) }
                else { statut = ("Match remis à simuler (proba figée effacée)", .secondary) }
            }
            .controlSize(.small)
            .disabled(!match.joue)

            Toggle("Forfait (exclure du modèle)", isOn: Binding(
                get: { match.forfait },
                set: { valeur in
                    if let e = vm.definirForfait(match.id, valeur) { statut = (e, Theme.perte) }
                    else { statut = valeur ? ("Marqué forfait — exclu du modèle", Theme.accent) : nil }
                }
            ))
            .toggleStyle(.checkbox)
            .font(Theme.legende)
            .help("Le score officiel compte au classement, mais le match n'alimente plus le modèle de forces.")

            Spacer(minLength: 0)

            if let statut {
                Text(statut.texte)
                    .font(Theme.legende)
                    .foregroundColor(statut.couleur)
                    .lineLimit(2)
            }
        }
    }

    private func validerScore() {
        guard let h = Int(butsDomicile.trimmingCharacters(in: .whitespaces)),
              let a = Int(butsExterieur.trimmingCharacters(in: .whitespaces)) else {
            statut = ("Score invalide", Theme.perte)
            return
        }
        if let e = vm.validerScore(match.id, domicile: h, exterieur: a) { statut = (e, Theme.perte) }
        else { statut = ("Score enregistré ✓", Theme.gain) }
    }

    // MARK: xG et minutes de but

    private var ligneXg: some View {
        HStack(spacing: Theme.espaceS) {
            Text("xG")
                .font(Theme.legende)
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            champDecimal("dom.", $xgDomicile)
            Text("–")
            champDecimal("ext.", $xgExterieur)
            Button("Valider xG") {
                guard let xg = xgSaisis else {
                    statut = ("xG invalides", Theme.perte)
                    return
                }
                if let e = vm.definirXg(match.id, xg) { statut = (e, Theme.perte) }
                else { statut = ("xG enregistrés ✓", Theme.gain) }
            }
            Button("Effacer xG") {
                xgDomicile = ""
                xgExterieur = ""
                if let e = vm.definirXg(match.id, nil) { statut = (e, Theme.perte) }
                else { statut = ("xG effacés", .secondary) }
            }
            Spacer(minLength: 0)
        }
        .controlSize(.small)
    }

    private var ligneMinutes: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Theme.espaceS) {
                Text("Buts (min.)")
                    .font(Theme.legende)
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .leading)
                TextField("ex. 23, 45+4", text: $minutesDomicile)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                Text("–")
                TextField("ex. 78", text: $minutesExterieur)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                Button("Valider minutes", action: validerMinutes)
                Button("Effacer") {
                    minutesDomicile = ""
                    minutesExterieur = ""
                    if let e = vm.definirMinutes(match.id, domicile: nil, exterieur: nil) { statutMinutes = (e, Theme.perte) }
                    else { statutMinutes = ("Minutes effacées", .secondary) }
                }
                Spacer(minLength: 0)
            }
            .controlSize(.small)
            .help("Minutes des buts de chaque équipe, séparées par des virgules (45+4 = temps additionnel). "
                  + "Servent uniquement à la règle Winamax des 2 buts d'avance.")

            if let statutMinutes {
                Text(statutMinutes.texte)
                    .font(Theme.legende)
                    .foregroundColor(statutMinutes.couleur)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 78)
            }
        }
    }

    private func validerMinutes() {
        guard match.joue, let h = match.butsDomicile, let a = match.butsExterieur else {
            statutMinutes = ("Le match doit d'abord être marqué joué", Theme.perte)
            return
        }
        do {
            let dom = try MinutesBut.liste(minutesDomicile)
            let ext = try MinutesBut.liste(minutesExterieur)
            try MinutesBut.valider(dom, ext, butsDomicile: h, butsExterieur: a)
            if let e = vm.definirMinutes(match.id, domicile: dom, exterieur: ext) { statutMinutes = (e, Theme.perte) }
            else { statutMinutes = ("Minutes enregistrées ✓", Theme.gain) }
        } catch {
            statutMinutes = (error.localizedDescription, Theme.perte)
        }
    }

    private func champDecimal(_ invite: String, _ texte: Binding<String>, largeur: CGFloat = 54) -> some View {
        TextField(invite, text: texte)
            .textFieldStyle(.roundedBorder)
            .monospacedDigit()
            .frame(width: largeur)
            .onChange(of: texte.wrappedValue) { _, nouveau in
                let filtre = SaisieNumerique.nettoyer(nouveau)
                if filtre != nouveau { texte.wrappedValue = filtre }
            }
    }

    /// xG saisis (même non validés), s'ils sont complets et positifs.
    private var xgSaisis: (Double, Double)? {
        let h = xgDomicile.trimmingCharacters(in: .whitespaces), a = xgExterieur.trimmingCharacters(in: .whitespaces)
        guard !h.isEmpty, !a.isEmpty else { return nil }
        let xh = SaisieNumerique.valeur(h), xa = SaisieNumerique.valeur(a)
        guard xh >= 0, xa >= 0, xh <= Limites.xg, xa <= Limites.xg else { return nil }
        return (xh, xa)
    }

    // MARK: Probabilités

    /// Probabilités affichées et leur provenance.
    private var probasAffichees: (p: [Double], source: String)? {
        if match.joue, match.fige, let p1 = match.figeP1, let pN = match.figePN, let p2 = match.figeP2 {
            let lh = match.figeLambdaDomicile.map { Format.nombre($0, decimales: 2, fixe: true) } ?? "—"
            let la = match.figeLambdaExterieur.map { Format.nombre($0, decimales: 2, fixe: true) } ?? "—"
            return ([p1, pN, p2], "Probabilités PRÉ-MATCH figées (λ dom. = \(lh) / λ ext. = \(la)) — non recalculées après le match")
        }
        if let xg = xgSaisis {
            return (Modele.probabilitesXg(xg.0, xg.1).triplet,
                    "Probabilités basées sur les xG saisis (\(Format.nombre(xg.0)) – \(Format.nombre(xg.1)))")
        }
        guard let p = vm.modele?.probas(match.domicile, match.exterieur) else { return nil }
        return (p.triplet, "Probabilités basées sur le modèle (λ dom. = \(Format.nombre(p.lambdaDomicile, decimales: 2, fixe: true)) / "
                + "λ ext. = \(Format.nombre(p.lambdaExterieur, decimales: 2, fixe: true)))")
    }

    @ViewBuilder
    private var probabilites: some View {
        if let affichees = probasAffichees {
            let implicites = Dictionary(uniqueKeysWithValues: match.livres.map { ($0.livre, Cotes.probabilitesImplicites($0.cotes)) })
            let reference = match.cotesReference.map(Cotes.probabilitesImplicites)
            VStack(alignment: .leading, spacing: Theme.espaceXS) {
                Text(affichees.source)
                    .font(Theme.legende.italic())
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Grid(alignment: .leading, horizontalSpacing: Theme.espaceM, verticalSpacing: 3) {
                    GridRow {
                        Text("")
                        Text("Modèle").bold()
                        ForEach(Bookmaker.allCases) { b in Text("vs \(b.titre)") }
                        if reference != nil { Text("vs réf.") }
                    }
                    .font(Theme.legende)
                    .foregroundColor(.secondary)

                    ForEach(Array(["1 (dom.)", "N", "2 (ext.)"].enumerated()), id: \.offset) { i, titre in
                        let pct = affichees.p[i] * 100
                        GridRow {
                            Text(titre)
                                .font(Theme.legende)
                                .foregroundColor(.secondary)
                            Text(Format.pourcent(pct, decimales: 1, fixe: true))
                                .font(Theme.corps.weight(.semibold))
                                .monospacedDigit()
                            ForEach(Bookmaker.allCases) { b in
                                if let imp = implicites[b] {
                                    ecart(pct - imp[i])
                                } else {
                                    Text("")
                                }
                            }
                            if let reference { ecart(pct - reference[i]) }
                        }
                    }
                }
                .help("Écart en points entre la probabilité du modèle et la probabilité implicite de chaque "
                      + "bookmaker et des cotes de référence du CSV (marge retirée) : vert = modèle plus optimiste.")

                if match.joue, let xh = match.xgDomicile, let xa = match.xgExterieur {
                    let post = Modele.probabilitesXg(xh, xa)
                    HStack(spacing: Theme.espaceS) {
                        Text("Après-match (xG réel) :")
                            .font(Theme.legende.weight(.semibold))
                            .foregroundColor(.secondary)
                        Text("1 = \(Format.pourcent(post.p1 * 100, decimales: 1, fixe: true))  "
                             + "N = \(Format.pourcent(post.pN * 100, decimales: 1, fixe: true))  "
                             + "2 = \(Format.pourcent(post.p2 * 100, decimales: 1, fixe: true))  "
                             + "(xG \(Format.nombre(xh)) – \(Format.nombre(xa)))")
                            .font(Theme.legende)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private func ecart(_ points: Double) -> some View {
        Text("\(Format.signe(points)) pts")
            .font(Theme.legende)
            .monospacedDigit()
            .foregroundColor(points >= 0 ? Theme.gain : Theme.perte)
    }

    // MARK: Cotes

    private var sectionCotes: some View {
        VStack(alignment: .leading, spacing: Theme.espaceXS) {
            DisclosureGroup(isExpanded: $cotesDepliees) {
                Grid(alignment: .leading, horizontalSpacing: Theme.espaceS, verticalSpacing: 4) {
                    GridRow {
                        Text("")
                        ForEach(["1", "N", "2"], id: \.self) { Text($0) }
                    }
                    .font(Theme.legende)
                    .foregroundColor(.secondary)
                    ForEach(Bookmaker.allCases) { b in
                        GridRow {
                            Text(b.titre)
                                .font(Theme.legende)
                                .foregroundColor(.secondary)
                            ForEach(0..<3, id: \.self) { i in
                                champDecimal("–", Binding(
                                    get: { cotes[b]?[i] ?? "" },
                                    set: { nouveau in
                                        cotes[b, default: ["", "", ""]][i] = nouveau
                                        coteSaisie(b)
                                    }), largeur: 58)
                            }
                        }
                    }
                }
                .padding(.top, Theme.espaceXS)
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                HStack(spacing: Theme.espaceS) {
                    Text("Cotes")
                        .font(Theme.corps.weight(.semibold))
                    Text(resumeMeilleuresCotes)
                        .font(Theme.legende)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            if let dc = texteDoubleChance {
                Text(dc)
                    .font(Theme.legende)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Les trois cotes d'un bookmaker, toutes > 1 ; sinon ses cotes sont effacées.
    private func coteSaisie(_ b: Bookmaker) {
        let valeurs = (cotes[b] ?? []).map { t -> Double? in
            let v = SaisieNumerique.valeur(t)
            return t.isEmpty || v <= 1 ? nil : v
        }
        let completes = valeurs.count == 3 && valeurs.allSatisfy { $0 != nil } ? valeurs.compactMap { $0 } : nil
        if let e = vm.definirCotes(match.id, b, completes) { statut = (e, Theme.perte) }
    }

    /// Meilleure cote par marché (line shopping) : c'est elle qui sert à l'espérance et aux paris.
    private var resumeMeilleuresCotes: String {
        guard let best = match.meilleuresCotes else { return "(aucune cote)" }
        guard let sources = match.sourcesMeilleuresCotes else {
            return "Cote moyenne en ligne → " + zip(["1", "N", "2"], best)
                .map { "\($0) : \(Format.nombre($1, decimales: 2, fixe: true))" }
                .joined(separator: "   ")
        }
        return "Meilleure cote → " + zip(["1", "N", "2"], zip(best, sources))
            .map { "\($0) : \(Format.nombre($1.0, decimales: 2, fixe: true)) (\($1.1.titre))" }
            .joined(separator: "   ")
    }

    /// Double chance calculée jambe par jambe sur la meilleure cote, parfois chez deux bookmakers.
    private var texteDoubleChance: String? {
        guard let best = match.meilleuresCotes else { return nil }
        let combos: [(String, Int, Int)] = [("1N", 0, 1), ("12", 0, 2), ("N2", 1, 2)]
        guard let s = match.sourcesMeilleuresCotes else {
            return "Cotes double chance (calculées, cote moyenne en ligne) : " + combos.map { nom, a, b in
                "\(nom) = \(Format.nombre(Cotes.combinee(best[a], best[b]), decimales: 2, fixe: true))"
            }.joined(separator: "   ")
        }
        return "Cotes double chance (calculées, meilleure cote par jambe) : " + combos.map { nom, a, b in
            let cote = Cotes.combinee(best[a], best[b])
            let detail = s[a] == s[b] ? s[a].titre : "\(s[a].titre) + \(s[b].titre)"
            return "\(nom) = \(Format.nombre(cote, decimales: 2, fixe: true)) (\(detail))"
        }.joined(separator: "   ")
    }
}
