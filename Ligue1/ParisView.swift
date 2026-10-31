//
//  ParisView.swift
//  Ligue1
//  © 2026 Stephen O'Donnell, Tanguy Labbe · GNU GPL v3 ou ultérieure (fichier LICENSE).
//
//  Simulation des paris : jauges (chacune rejoue tout l'historique), quatre
//  bankrolls, dépôts/retraits, paris manuels et exclus, graphiques, paris
//  regroupés par journée et paris en attente.
//  Conseils de paris : les paris en attente présentés comme des conseils, avec
//  la précision mesurée sur les saisons passées.
//
import SwiftUI
import Charts

extension MethodeMise {
    var couleur: Color {
        switch self {
        case .fixe:       return .blue
        case .kelly:      return .red
        case .demiKelly:  return .orange
        case .quartKelly: return .green
        }
    }
}

struct ParisView: View {
    @EnvironmentObject var vm: Ligue1ViewModel
    /// nil = seule la dernière journée est dépliée.
    @State private var depliees: Set<Int>?

    var body: some View {
        let r = vm.resultatParis

        ScrollView {
            VStack(alignment: .leading, spacing: Theme.espaceL) {
                if !vm.peutModifier(.reglages) {
                    Bandeau(titre: "Réglages bloqués",
                            lignes: ["\(FichierDonnees.reglages.nom) n'a pas pu être chargé : les jauges ne sont pas enregistrées."])
                }

                enTete(r)
                jauges
                PanneauMouvements()
                PanneauPariManuel()
                PanneauExclusions()

                Text(avertissement(r))
                    .font(Theme.legende)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                graphiques(r)
                historique(r)

                Text("La cote double chance est calculée automatiquement à partir des cotes 1/N/2. Son espérance ne peut "
                     + "jamais dépasser celle du meilleur des deux marchés simples qui la composent : c'est un pari "
                     + "complémentaire qui réduit la variance, pas un moyen de trouver de la valeur cachée. Elle est réglée "
                     + "jambe par jambe (les deux mises séparées peuvent gagner en même temps, notamment via la règle des "
                     + "2 buts d'avance). Gain d'une journée = (bankroll après ÷ bankroll avant) − 1. Gain global (tuiles du "
                     + "haut) = bankroll actuelle ÷ (dépôts appliqués − retraits appliqués) − 1, les retraits comptant pour "
                     + "leur montant réellement appliqué (après plafonnement éventuel).")
                    .font(Theme.legende)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
        }
    }

    // MARK: En-tête : seuil et bankrolls

    private func enTete(_ r: ResultatParis) -> some View {
        let gagnes = r.paris.filter(\.gagne).count
        return VStack(alignment: .leading, spacing: Theme.espaceM) {
            HStack(alignment: .top, spacing: Theme.espaceM) {
                ForEach(MethodeMise.allCases) { k in
                    let g = r.gainsPourcent[k]
                    TuileChiffre(titre: k.titre, valeur: Format.euro(r.bankrolls[k]),
                                 detail: "\(Format.signe(g)) % sur l'argent engagé",
                                 icone: "banknote", couleurValeur: k.couleur)
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.espaceM) {
                Label {
                    Text("\(gagnes) pari\(gagnes > 1 ? "s" : "") gagné\(gagnes > 1 ? "s" : "") sur \(r.paris.count) au total"
                         + (r.paris.isEmpty ? "" : " (\(Format.pourcent(Double(gagnes) / Double(r.paris.count) * 100, decimales: 0)) de réussite)"))
                } icon: {
                    Image(systemName: "chart.bar.fill")
                }
                if !r.enAttente.isEmpty {
                    Label("\(r.enAttente.count) en attente", systemImage: "hourglass")
                        .foregroundColor(Theme.accent)
                }
            }
            .font(Theme.section)
        }
    }

    // MARK: Jauges

    private var jauges: some View {
        VStack(alignment: .leading, spacing: Theme.espaceS) {
            Text("Réglages de la sélection")
                .font(Theme.section)
            Jauge(titre: "Seuil d'espérance", valeur: reglage(\.seuil, arrondi: 100), plage: 1.0...1.3, pas: 0.01,
                  texte: "≥ \(Format.nombre(vm.reglages.seuil, decimales: 2, fixe: true))",
                  note: "espérance minimale (cote × probabilité du modèle) pour jouer un marché")
            Jauge(titre: "Poids du modèle", valeur: reglage(\.poidsModele, arrondi: 100), plage: 0.0...1.0, pas: 0.05,
                  texte: Format.nombre(vm.reglages.poidsModele, decimales: 2, fixe: true),
                  note: "probabilité = poids × modèle + (1 − poids) × marché (cote d'ouverture, marge retirée) ; "
                  + "0 = marché seul : parier là où la meilleure cote dépasse la cote juste de Pinnacle"
                  + (vm.calibration.map { " ; optimum du backtest \(Format.nombre($0.poidsModeleOptimal, decimales: 1, fixe: true))" } ?? ""))
            Jauge(titre: "Cote minimale autorisée", valeur: reglage(\.coteMin, arrondi: 100), plage: 1.0...5.0, pas: 0.1,
                  texte: "≥ \(Format.nombre(vm.reglages.coteMin, decimales: 2, fixe: true))",
                  note: "en dessous, l'espérance est trop sensible au bruit")
            Jauge(titre: "Cote maximale autorisée", valeur: reglage(\.coteMax, arrondi: 10), plage: 1.0...20.0, pas: 0.1,
                  texte: "≤ \(Format.nombre(vm.reglages.coteMax, decimales: 1, fixe: true))",
                  note: "le modèle est structurellement moins fiable sur les très gros outsiders, Kelly amplifie mécaniquement toute erreur")
            Jauge(titre: "Cote minimale double chance", valeur: reglage(\.coteMinDoubleChance, arrondi: 100), plage: 1.0...3.0, pas: 0.05,
                  texte: "≥ \(Format.nombre(vm.reglages.coteMinDoubleChance, decimales: 2, fixe: true))",
                  note: "en plus d'un pari simple déjà possible, jamais à sa place")
            Jauge(titre: "Mise fixe (% bankroll)", valeur: reglage(\.miseFixe, arrondi: 1000), plage: 0.01...0.20, pas: 0.005,
                  texte: Format.pourcent(vm.reglages.miseFixe * 100, decimales: 1, fixe: true),
                  note: "s'applique à la colonne « Mise fixe » et aux paris manuels")
            Jauge(titre: "Bankroll de départ", valeur: reglage(\.bankrollDepart, arrondi: 1), plage: 100...10_000, pas: 50,
                  texte: Format.euro(vm.reglages.bankrollDepart),
                  note: "base de départ des 4 bankrolls — rejoue tout")
            Text("La jauge de cote se base sur la cote médiane entre bookmakers ; l'espérance et la mise utilisent la meilleure cote.")
                .font(Theme.legende)
                .foregroundColor(.secondary)
        }
        .padding(Theme.espaceM)
        .carte()
        .disabled(!vm.peutModifier(.reglages))
    }

    private func reglage(_ chemin: WritableKeyPath<Reglages, Double>, arrondi: Double) -> Binding<Double> {
        Binding(
            get: { vm.reglages[keyPath: chemin] },
            set: { v in vm.modifierReglages { $0[keyPath: chemin] = (v * arrondi).rounded() / arrondi } }
        )
    }

    private func avertissement(_ r: ResultatParis) -> String {
        let candidats = vm.ligue.matchsJoues.filter { $0.meilleuresCotes != nil && $0.fige }.count
        let distincts = Set(r.paris.map { "\($0.journee)|\($0.domicile)|\($0.exterieur)" }).count
        let g = vm.reglages
        return "\(r.paris.count) pari(s) retenu(s) sur \(distincts) match(s) distinct(s) (sur \(candidats) match(s) joué(s) "
            + "avec cotes saisies et probabilité figée) — seuil d'espérance ≥ \(Format.nombre(g.seuil, decimales: 2, fixe: true)), "
            + "cote \(Format.nombre(g.coteMin, decimales: 2, fixe: true))–\(Format.nombre(g.coteMax, decimales: 1, fixe: true)), "
            + "double chance ≥ \(Format.nombre(g.coteMinDoubleChance, decimales: 2, fixe: true)), "
            + "mise fixe \(Format.pourcent(g.miseFixe * 100, decimales: 1, fixe: true)). "
            + "Seuls les matchs joués avec des cotes saisies et une probabilité pré-match figée entrent dans la simulation."
    }

    // MARK: Graphiques

    /// Un graphique par méthode, chacun à sa propre échelle : une bankroll proche
    /// de 0 n'écrase pas la lecture des trois autres.
    private func graphiques(_ r: ResultatParis) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.espaceM), GridItem(.flexible())], spacing: Theme.espaceM) {
            ForEach(MethodeMise.allCases) { k in
                GraphiqueBankroll(methode: k, points: r.historique, finale: r.bankrolls[k],
                                  gain: r.gainsPourcent[k], depart: vm.reglages.bankrollDepart)
            }
        }
    }

    // MARK: Historique par journée

    private func historique(_ r: ResultatParis) -> some View {
        let ouvertes = depliees ?? Set(r.journees.last.map { [$0.journee] } ?? [])
        return VStack(alignment: .leading, spacing: Theme.espaceS) {
            Text("Paris par journée")
                .font(Theme.section)

            if !r.enAttente.isEmpty {
                VStack(alignment: .leading, spacing: Theme.espaceS) {
                    Label("En attente — \(r.enAttente.count) candidat(s) sur des matchs pas encore joués "
                          + "(probabilité en direct, pas d'impact sur la bankroll)", systemImage: "hourglass")
                        .font(Theme.section)
                        .foregroundColor(Theme.accent)
                    TableauParis(paris: r.enAttente.sorted { $0.journee < $1.journee })
                }
                .padding(Theme.espaceM)
                .background(Theme.accent.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: Theme.rayon, style: .continuous))
            }

            if r.journees.isEmpty {
                EtatVide(icone: "eurosign.circle", titre: "Aucun pari retenu",
                         detail: "Saisissez des cotes sur des matchs joués, ou assouplissez les jauges.")
            }

            ForEach(r.journees.reversed()) { j in
                DisclosureGroup(isExpanded: Binding(
                    get: { ouvertes.contains(j.journee) },
                    set: { ouvert in
                        var s = ouvertes
                        if ouvert { s.insert(j.journee) } else { s.remove(j.journee) }
                        depliees = s
                    }
                )) {
                    TableauParis(paris: j.paris)
                        .padding(.top, Theme.espaceXS)
                } label: {
                    HStack {
                        Text("Journée \(j.journee)  —  \(j.gagnes)/\(j.paris.count) pari\(j.paris.count > 1 ? "s" : "") gagné\(j.gagnes > 1 ? "s" : "")")
                            .font(Theme.corps.weight(.semibold))
                            .foregroundColor(j.gagnes * 2 >= j.paris.count ? Theme.gain : .secondary)
                        Spacer()
                        Text(MethodeMise.allCases.map { "\($0.titre) : \(Format.signe(j.pourcentage[$0])) %" }
                                .joined(separator: "   "))
                            .font(Theme.legende)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
                .padding(Theme.espaceS)
                .carte(Theme.rayonPetit)
            }
        }
    }
}

// MARK: - Jauge

private struct Jauge: View {
    let titre: String
    @Binding var valeur: Double
    let plage: ClosedRange<Double>
    let pas: Double
    let texte: String
    let note: String

    var body: some View {
        HStack(spacing: Theme.espaceM) {
            Text(titre)
                .font(Theme.corps)
                .frame(width: 210, alignment: .leading)
            Slider(value: $valeur, in: plage, step: pas)
                .frame(width: 200)
            Text(texte)
                .font(Theme.corps.weight(.semibold))
                .foregroundColor(Theme.accent)
                .monospacedDigit()
                .frame(width: 80, alignment: .leading)
            Text(note)
                .font(Theme.legende)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Graphique d'une bankroll

private struct GraphiqueBankroll: View {
    let methode: MethodeMise
    let points: [PointBankroll]
    let finale: Double
    let gain: Double
    let depart: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.espaceXS) {
            Text("\(methode.titre) — \(Format.euro(finale))  (\(Format.signe(gain)) %)")
                .font(Theme.section)
            Chart {
                RuleMark(y: .value("Départ", depart))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(Color.secondary.opacity(0.6))
                ForEach(points) { p in
                    if case .mouvement(let montant) = p.nature {
                        RuleMark(x: .value("Étape", p.indice))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                            .foregroundStyle((montant >= 0 ? Theme.gain : Theme.perte).opacity(0.6))
                    }
                    LineMark(x: .value("Étape", p.indice), y: .value("Bankroll", p.bankrolls[methode]))
                        .foregroundStyle(methode.couleur)
                        .lineStyle(StrokeStyle(lineWidth: 1.6))
                    PointMark(x: .value("Étape", p.indice), y: .value("Bankroll", p.bankrolls[methode]))
                        .foregroundStyle(methode.couleur)
                        .symbolSize(10)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 8)) { v in
                    AxisGridLine().foregroundStyle(Theme.piste)
                    AxisValueLabel {
                        if let i = v.as(Int.self), points.indices.contains(i) {
                            Text(points[i].journee == 0 ? "Départ" : "J\(points[i].journee)")
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { v in
                    AxisGridLine().foregroundStyle(Theme.piste)
                    AxisValueLabel {
                        if let e = v.as(Double.self) { Text(Format.euro(e)) }
                    }
                }
            }
            .frame(height: 180)
        }
        .padding(Theme.espaceM)
        .carte()
    }
}

// MARK: - Tableau des paris

private struct TableauParis: View {
    @EnvironmentObject var vm: Ligue1ViewModel
    let paris: [Pari]

    static let largeurs: [CGFloat] = [150, 96, 56, 46, 46, 108, 108, 108, 108, 120, 64]
    static let titres = ["Match", "Marché", "p modèle", "Cote", "EV"] + MethodeMise.allCases.map(\.titreCourt) + ["Résultat", ""]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(Array(Self.titres.enumerated()), id: \.offset) { i, t in
                        Text(t).frame(width: Self.largeurs[i], alignment: .leading)
                    }
                }
                .font(Theme.legende.weight(.semibold))
                .foregroundColor(.secondary)
                ForEach(paris) { p in
                    LignePari(pari: p)
                    Divider()
                }
            }
        }
    }
}

private struct LignePari: View {
    @EnvironmentObject var vm: Ligue1ViewModel
    let pari: Pari

    private var l: [CGFloat] { TableauParis.largeurs }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Ecusson(equipe: pari.domicile, taille: 16)
                    Text("\(Ecussons.initiales(pari.domicile)) – \(Ecussons.initiales(pari.exterieur))")
                    Ecusson(equipe: pari.exterieur, taille: 16)
                }
                .frame(width: l[0], alignment: .leading)
                .help("J\(pari.journee) · \(pari.domicile) – \(pari.exterieur)")
                Text(pari.marche.titre + (pari.manuel ? " [manuel]" : ""))
                    .frame(width: l[1], alignment: .leading)
                Text(Format.pourcent(pari.p * 100, decimales: 1, fixe: true)).frame(width: l[2], alignment: .leading)
                Text(Format.nombre(pari.cote, decimales: 2, fixe: true))
                    .frame(width: l[3], alignment: .leading)
                    .help(pari.source.isEmpty ? "" : "Meilleure cote : \(pari.source.replacingOccurrences(of: "+", with: " + "))")
                Text(Format.nombre(pari.esperance, decimales: 3, fixe: true)).frame(width: l[4], alignment: .leading)
                ForEach(Array(MethodeMise.allCases.enumerated()), id: \.offset) { i, k in
                    Text("\(Self.montant(pari.mises[k])) (\(Format.nombre(pari.misesPourcent[k], decimales: 1, fixe: true)) %)")
                        .lineLimit(1)
                        .fixedSize()
                        .frame(width: l[5 + i], alignment: .leading)
                }
                resultat.frame(width: l[9], alignment: .leading)
                Button("Exclure") {
                    if let e = vm.exclure(PariExclu(journee: pari.journee, home: pari.domicile, away: pari.exterieur,
                                                    market: pari.marche)) {
                        vm.log(e, level: .warning)
                    }
                }
                .controlSize(.small)
                .disabled(!vm.peutModifier(.parisExclus))
                .frame(width: l[10], alignment: .leading)
            }
            .font(Theme.legende)
            .monospacedDigit()

            if !pari.enAttente {
                HStack(spacing: 6) {
                    Text(pari.source).frame(width: l[0] + l[1] + l[2] + l[3] + l[4] + 24, alignment: .leading)
                        .foregroundColor(.secondary)
                    ForEach(Array(MethodeMise.allCases.enumerated()), id: \.offset) { i, k in
                        let g = pari.gains[k]
                        let pct = pari.mises[k] > 0 ? g / pari.mises[k] * pari.misesPourcent[k] : 0
                        Text("↳ \(g >= 0 ? "+" : "")\(Self.montant(g)) (\(Format.signe(pct)) %)")
                            .foregroundColor(g >= 0 ? Theme.gain : Theme.perte)
                            .lineLimit(1)
                            .fixedSize()
                            .frame(width: l[5 + i], alignment: .leading)
                    }
                }
                .font(.caption2)
                .monospacedDigit()
            } else if !pari.source.isEmpty {
                Text(pari.source).font(.caption2).foregroundColor(.secondary)
            }

            if let rep = pari.repartition {
                Text(texteRepartition(rep))
                    .font(.caption2.italic())
                    .foregroundColor(.secondary)
            }

            Text("À titre indicatif (EV des 6 marchés) — " + Marche.allCases.compactMap { m in
                pari.tousMarches[m].map { "\(m.titre) = \(Format.nombre($0.esperance, decimales: 2, fixe: true))" }
            }.joined(separator: "  ·  "))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }

    /// Montant au dixième d'euro, comme le tableau de l'app Python.
    static func montant(_ v: Double) -> String { "\(Format.nombre(v, decimales: 1, fixe: true)) €" }

    @ViewBuilder
    private var resultat: some View {
        if pari.enAttente {
            Text("EN ATTENTE").bold().foregroundColor(Theme.accent)
        } else if pari.gagne {
            Text(pari.gagneParAvance ? "GAGNÉ (2 buts av.)" : "GAGNÉ").bold().foregroundColor(Theme.gain)
        } else {
            Text("PERDU").bold().foregroundColor(Theme.perte)
        }
    }

    private func texteRepartition(_ r: Repartition) -> String {
        var texte: String
        let livres = pari.source.split(separator: "+").map(String.init)
        if livres.count == 2 {
            texte = "↳ double chance : \(Format.euro(r.miseA, decimales: true)) sur \(r.jambeA.titre) chez \(livres[0]) "
                + "+ \(Format.euro(r.miseB, decimales: true)) sur \(r.jambeB.titre) chez \(livres[1]) (mise fixe)"
        } else {
            texte = "↳ double chance : \(Format.euro(r.miseA, decimales: true)) sur \(r.jambeA.titre) "
                + "+ \(Format.euro(r.miseB, decimales: true)) sur \(r.jambeB.titre) (mise fixe)"
        }
        if let j = pari.jambes {
            func etat(_ gagnee: Bool, _ avance: Bool) -> String {
                gagnee ? "gagné" + (avance ? " (2 buts av.)" : "") : "perdu"
            }
            texte += "  —  \(j.jambeA.titre) : \(etat(j.gagneeA, j.avanceA))  ·  \(j.jambeB.titre) : \(etat(j.gagneeB, j.avanceB))"
        }
        return texte
    }
}

// MARK: - Dépôts / retraits

private struct PanneauMouvements: View {
    @EnvironmentObject var vm: Ligue1ViewModel
    @State private var journee = ""
    @State private var montant = ""
    @State private var note = ""
    @State private var statut: (texte: String, ok: Bool)?

    private var journeeCourante: Int { vm.ligue.matchsJoues.map(\.journee).max() ?? 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.espaceS) {
            Text("Dépôts / retraits simulés")
                .font(Theme.section)
            Text("Mouvement fictif ancré à une journée, appliqué aux 4 bankrolls avant les paris de cette journée. "
                 + "Un retrait est plafonné au montant disponible.")
                .font(Theme.legende)
                .foregroundColor(.secondary)

            HStack(spacing: Theme.espaceS) {
                Text("Journée").font(Theme.legende).foregroundColor(.secondary)
                TextField("\(journeeCourante)", text: $journee)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
                    .onChange(of: journee) { _, v in
                        let f = String(v.filter(\.isNumber).prefix(3))
                        if f != v { journee = f }
                    }
                Text("Montant € (négatif = retrait)").font(Theme.legende).foregroundColor(.secondary)
                TextField("ex. 500 ou -200", text: $montant)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 110)
                    .onChange(of: montant) { _, v in
                        let negatif = v.hasPrefix("-")
                        let f = (negatif ? "-" : "") + SaisieNumerique.nettoyer(v)
                        if f != v { montant = f }
                    }
                Text("Note").font(Theme.legende).foregroundColor(.secondary)
                TextField("optionnel", text: $note)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                Button("Ajouter", action: ajouter)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                if let statut {
                    Label(statut.texte, systemImage: statut.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(Theme.legende)
                        .foregroundColor(statut.ok ? Theme.gain : .orange)
                }
                Spacer(minLength: 0)
            }
            .controlSize(.small)

            if vm.mouvements.isEmpty {
                Text("Aucun dépôt/retrait simulé pour l'instant.")
                    .font(Theme.legende)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(vm.mouvements.enumerated()).sorted { $0.element.journee < $1.element.journee }, id: \.offset) { i, e in
                    HStack(spacing: Theme.espaceS) {
                        Text(e.resume)
                            .foregroundColor(e.amount >= 0 ? Theme.gain : Theme.perte)
                        Button {
                            if let erreur = vm.supprimerMouvement(at: i) { statut = (erreur, false) }
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Supprimer")
                    }
                    .font(Theme.corps)
                }
            }
        }
        .padding(Theme.espaceM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .carte()
        .disabled(!vm.peutModifier(.mouvements))
    }

    private func ajouter() {
        let j = journee.isEmpty ? journeeCourante : Int(journee) ?? 0
        let negatif = montant.hasPrefix("-")
        let v = SaisieNumerique.valeur(String(montant.drop(while: { $0 == "-" }))) * (negatif ? -1 : 1)
        guard v != 0 else {
            statut = ("Journée/montant invalide", false)
            return
        }
        let note = self.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let erreur = vm.ajouterMouvement(Mouvement(journee: j, amount: v, note: note)) {
            statut = (erreur, false)
            return
        }
        journee = ""
        montant = ""
        self.note = ""
        statut = ("Ajouté", true)
    }
}

// MARK: - Paris manuels et exclus

/// Matchs proposés : ceux qui ont au moins une cote saisie.
private struct ChoixMatchMarche: View {
    @EnvironmentObject var vm: Ligue1ViewModel
    @Binding var matchID: Match.ID?
    @Binding var marche: Marche

    var body: some View {
        let matchs = vm.ligue.matches.filter { $0.meilleuresCotes != nil }
        HStack(spacing: Theme.espaceS) {
            Picker("Match", selection: Binding(get: { matchID ?? matchs.first?.id }, set: { matchID = $0 })) {
                if matchs.isEmpty { Text("(aucun match avec cotes)").tag(Match.ID?.none) }
                ForEach(matchs) { m in
                    Text("J\(m.journee) · \(m.libelle)").tag(Match.ID?.some(m.id))
                }
            }
            .frame(width: 360)
            Picker("Marché", selection: $marche) {
                ForEach(Marche.allCases) { Text($0.titre).tag($0) }
            }
            .frame(width: 200)
        }
    }

    static func selection(_ vm: Ligue1ViewModel, _ id: Match.ID?) -> Match? {
        let matchs = vm.ligue.matches.filter { $0.meilleuresCotes != nil }
        return matchs.first { $0.id == (id ?? matchs.first?.id) }
    }
}

private struct PanneauPariManuel: View {
    @EnvironmentObject var vm: Ligue1ViewModel
    @State private var matchID: Match.ID?
    @State private var marche: Marche = .un
    @State private var statut: (texte: String, ok: Bool)?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.espaceS) {
            Text("Ajouter un pari manuellement (même hors sélection)")
                .font(Theme.section)
            Text("Marqué « [manuel] » ; il mise toujours la mise fixe sur les 4 colonnes (Kelly miserait 0 € sans avantage du modèle).")
                .font(Theme.legende)
                .foregroundColor(.secondary)
            HStack(spacing: Theme.espaceS) {
                ChoixMatchMarche(matchID: $matchID, marche: $marche)
                Button("Forcer ce pari") {
                    guard let m = ChoixMatchMarche.selection(vm, matchID) else {
                        statut = ("Aucun match sélectionnable", false)
                        return
                    }
                    statut = vm.ajouterPariManuel(PariManuel(journee: m.journee, home: m.domicile, away: m.exterieur,
                                                             market: marche)).map { ($0, false) } ?? ("Pari manuel ajouté", true)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                if let statut {
                    Label(statut.texte, systemImage: statut.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(Theme.legende)
                        .foregroundColor(statut.ok ? Theme.gain : .orange)
                }
                Spacer(minLength: 0)
            }
            .controlSize(.small)

            if vm.parisManuels.isEmpty {
                Text("Aucun pari manuel pour l'instant.")
                    .font(Theme.legende)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(vm.parisManuels.enumerated()), id: \.offset) { _, b in
                    HStack(spacing: Theme.espaceS) {
                        Text(b.resume)
                        Button {
                            if let e = vm.supprimerPariManuel(b) { statut = (e, false) }
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Supprimer")
                    }
                    .font(Theme.corps)
                }
            }
        }
        .padding(Theme.espaceM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .carte()
        .disabled(!vm.peutModifier(.parisManuels))
    }
}

private struct PanneauExclusions: View {
    @EnvironmentObject var vm: Ligue1ViewModel
    @State private var matchID: Match.ID?
    @State private var marche: Marche = .un
    @State private var statut: (texte: String, ok: Bool)?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.espaceS) {
            Text("Exclure un pari présélectionné")
                .font(Theme.section)
            Text("Écarte un marché que la sélection aurait retenu — ici, même avant qu'il soit détecté, "
                 + "ou avec le bouton « Exclure » d'une ligne du tableau.")
                .font(Theme.legende)
                .foregroundColor(.secondary)
            HStack(spacing: Theme.espaceS) {
                ChoixMatchMarche(matchID: $matchID, marche: $marche)
                Button("Exclure ce pari") {
                    guard let m = ChoixMatchMarche.selection(vm, matchID) else {
                        statut = ("Aucun match sélectionnable", false)
                        return
                    }
                    statut = vm.exclure(PariExclu(journee: m.journee, home: m.domicile, away: m.exterieur,
                                                  market: marche)).map { ($0, false) } ?? ("Pari exclu", true)
                }
                if let statut {
                    Label(statut.texte, systemImage: statut.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(Theme.legende)
                        .foregroundColor(statut.ok ? Theme.gain : .orange)
                }
                Spacer(minLength: 0)
            }
            .controlSize(.small)

            if vm.parisExclus.isEmpty {
                Text("Aucun pari exclu pour l'instant.")
                    .font(Theme.legende)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(vm.parisExclus.enumerated()), id: \.offset) { _, b in
                    HStack(spacing: Theme.espaceS) {
                        Text(b.resume)
                        Button {
                            if let e = vm.supprimerExclusion(b) { statut = (e, false) }
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Rétablir")
                    }
                    .font(Theme.corps)
                }
            }
        }
        .padding(Theme.espaceM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .carte()
        .disabled(!vm.peutModifier(.parisExclus))
    }
}

// MARK: - Conseils de paris

/// Paris conseillés sur les matchs à venir (mêmes règles et jauges que la
/// simulation) ; pour chacun, la précision mesurée sur les saisons passées.
struct ConseilsView: View {
    @EnvironmentObject var vm: Ligue1ViewModel

    var body: some View {
        let r = vm.resultatParis
        let conseils = r.enAttente.sorted {
            ($0.journee, $0.domicile, $0.marche.rawValue) < ($1.journee, $1.domicile, $1.marche.rawValue)
        }
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.espaceL) {
                synthese
                if conseils.isEmpty {
                    EtatVide(icone: "lightbulb", titre: "Aucun pari conseillé pour l'instant",
                             detail: "Aucun match à venir ne passe le seuil d'espérance "
                             + "(\(Format.nombre(vm.reglages.seuil, decimales: 2, fixe: true))) avec les cotes connues. "
                             + "« Mettre à jour en ligne » charge les matchs de la semaine et leurs cotes (fixtures.csv).")
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 480), spacing: Theme.espaceM, alignment: .top)],
                              alignment: .leading, spacing: Theme.espaceM) {
                        ForEach(conseils) { p in
                            CarteConseil(pari: p, match: vm.match("\(p.journee)|\(p.domicile)|\(p.exterieur)"),
                                         precision: vm.precision, poids: vm.reglages.poidsModele)
                                // Hauteur réelle du texte replié : sinon les lignes de la grille se chevauchent.
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if let precision = vm.precision {
                    detail(precision)
                }
                Text("Conseils calculés par le modèle à partir des données publiques de football-data.co.uk, avec les jauges "
                     + "de la simulation (seuil d'espérance, cotes min/max, mises). La précision affichée est celle mesurée sur "
                     + "les saisons passées : elle ne garantit rien pour la suite. Cote « Moy. en ligne » : moyenne du marché, "
                     + "souvent un peu au-dessus des bookmakers français ; saisissez leurs cotes (Journées & cotes) pour un "
                     + "conseil exact. Ne misez que ce que vous pouvez perdre ; aide : Joueurs Info Service, 09 74 75 13 13.")
                    .font(Theme.legende)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
        }
        .onAppear { vm.lancerPrecision() }
        .onChange(of: vm.reglages) { _, _ in vm.lancerPrecision() }
    }

    // MARK: Synthèse

    @ViewBuilder
    private var synthese: some View {
        if let p = vm.precision {
            let g = p.global
            VStack(alignment: .leading, spacing: Theme.espaceM) {
                HStack(spacing: Theme.espaceM) {
                    TuileChiffre(titre: "Paris sur \(p.saisons.count) saisons évaluées", valeur: "\(g.n)",
                                 detail: "règle actuelle, cote moyenne en ligne (la 1re saison chargée sert de départ)",
                                 icone: "list.bullet")
                    TuileChiffre(titre: "Réussite", valeur: Format.pourcent(g.tauxReussite * 100, decimales: 1, fixe: true),
                                 detail: "cote moyenne \(Format.nombre(g.coteMoyenne, decimales: 2, fixe: true))",
                                 icone: "target")
                    TuileChiffre(titre: "Rendement (ROI)", valeur: ConseilsView.pourcentSigne(g.roi),
                                 detail: "IC 95 % : \(ConseilsView.intervalle(g.ic))", icone: "chart.line.uptrend.xyaxis",
                                 couleurValeur: ConseilsView.couleur(g.verdict))
                    TuileChiffre(titre: "Log-loss modèle / marché",
                                 valeur: "\(Format.nombre(p.modele.logLoss, decimales: 3, fixe: true)) / "
                                 + Format.nombre(p.marche.logLoss, decimales: 3, fixe: true),
                                 detail: "plus bas = plus précis, \(p.n) matchs", icone: "scope",
                                 couleurValeur: p.modele.logLoss < p.marche.logLoss ? Theme.gain : .primary)
                }
                .fixedSize(horizontal: false, vertical: true)
                Label(ConseilsView.phrase(g, p), systemImage: ConseilsView.icone(g.verdict))
                    .font(Theme.corps)
                    .foregroundColor(ConseilsView.couleur(g.verdict))
                    .fixedSize(horizontal: false, vertical: true)
                if p.sansOuverture > 0 {
                    Label("\(p.sansOuverture) match(s) de l'historique sans cotes d'ouverture : le mélange y prend la "
                          + "clôture, connue après coup, ce qui flatte le résultat. « Mettre à jour en ligne » "
                          + "(Paramètres › Saison) recharge ces saisons.", systemImage: "exclamationmark.triangle.fill")
                        .font(Theme.legende)
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else if vm.precisionEnCours {
            HStack(spacing: Theme.espaceS) {
                ProgressView().controlSize(.small)
                Text("Mesure de la précision sur les saisons passées…")
                    .font(Theme.corps)
            }
        } else {
            Bandeau(titre: "Précision inconnue",
                    lignes: ["Il faut au moins deux saisons d'historique : « Mettre à jour en ligne » (Paramètres › Saison) "
                             + "charge les 10 dernières saisons de Ligue 1."])
        }
    }

    static func phrase(_ g: BilanParis, _ p: ResultatPrecision) -> String {
        let periode = "\(p.saisons.first ?? "") à \(p.saisons.last ?? "")"
        switch g.verdict {
        case .avantage:
            return "Sur \(periode), cette règle a gagné de l'argent de façon significative : les conseils ont un avantage "
                + "mesuré, à confirmer avec les cotes de votre bookmaker."
        case .incertain:
            return "Sur \(periode), le résultat de cette règle ne se distingue pas du hasard : aucun avantage démontré. "
                + "Les conseils restent des paris risqués ; misez petit ou pas du tout."
        case .perte:
            return "Sur \(periode), cette règle a perdu de l'argent de façon significative : le marché est plus précis "
                + "que le modèle. Il vaut mieux ne pas suivre ces conseils."
        }
    }

    static func couleur(_ v: BilanParis.Verdict) -> Color {
        switch v {
        case .avantage:  return Theme.gain
        case .incertain: return .orange
        case .perte:     return Theme.perte
        }
    }

    static func icone(_ v: BilanParis.Verdict) -> String {
        switch v {
        case .avantage:  return "checkmark.seal.fill"
        case .incertain: return "questionmark.circle.fill"
        case .perte:     return "xmark.octagon.fill"
        }
    }

    static func pourcentSigne(_ v: Double) -> String {
        (v >= 0 ? "+" : "") + Format.pourcent(v * 100, decimales: 1, fixe: true)
    }

    static func intervalle(_ i: Intervalle) -> String {
        "\(pourcentSigne(i.bas)) à \(pourcentSigne(i.haut))"
    }

    /// Bilan historique le plus proche : même tranche d'espérance (30 paris au moins), sinon la règle entière.
    static func preuve(_ pari: Pari, _ precision: ResultatPrecision?) -> (titre: String, bilan: BilanParis)? {
        guard let precision else { return nil }
        if let l = precision.bilan(esperance: pari.esperance), l.bilan.n >= 30 {
            return ("Paris d'espérance \(l.titre)", l.bilan)
        }
        return ("Tous les paris conseillés", precision.global)
    }

    /// Parier si la tranche a gagné de façon significative ; s'abstenir si elle a
    /// perdu, ou si rien n'y est démontré alors que la règle entière perd.
    static func recommandation(_ pari: Pari, _ precision: ResultatPrecision?)
        -> (texte: String, verdict: BilanParis.Verdict?) {
        guard let v = preuve(pari, precision)?.bilan.verdict else { return ("Précision inconnue", nil) }
        let global = precision?.global.verdict
        switch v {
        case .avantage:                       return ("Parier", v)
        case .incertain where global == .perte: return ("Ne pas parier", .perte)
        case .incertain:                      return ("Petite mise au plus", v)
        case .perte:                          return ("Ne pas parier", v)
        }
    }

    // MARK: Détail de la précision

    private func detail(_ p: ResultatPrecision) -> some View {
        HStack(alignment: .top, spacing: Theme.espaceM) {
            VStack(alignment: .leading, spacing: Theme.espaceXS) {
                Text("Fiabilité des probabilités").font(Theme.section)
                Text("Quand le modèle annonce… l'issue s'est produite (IC 95 %)").font(Theme.legende).foregroundColor(.secondary)
                Grid(alignment: .trailing, horizontalSpacing: Theme.espaceM, verticalSpacing: 3) {
                    GridRow {
                        Text("Annoncé").gridColumnAlignment(.leading)
                        Text("Réalisé")
                        Text("IC 95 %")
                        Text("Cas")
                    }
                    .font(Theme.legende.weight(.semibold))
                    .foregroundColor(.secondary)
                    ForEach(p.fiabilite) { t in
                        GridRow {
                            Text("\(Int(t.bas * 100))–\(Int(t.haut * 100)) % (moy. \(Format.pourcent(t.predite * 100, decimales: 1, fixe: true)))")
                                .gridColumnAlignment(.leading)
                            Text(Format.pourcent(t.observee * 100, decimales: 1, fixe: true))
                                .foregroundColor(t.ic.bas <= t.predite && t.predite <= t.ic.haut ? .primary : .orange)
                            Text("\(Format.pourcent(t.ic.bas * 100, decimales: 1, fixe: true))–\(Format.pourcent(t.ic.haut * 100, decimales: 1, fixe: true))")
                            Text("\(t.n)")
                        }
                        .font(Theme.corps)
                        .monospacedDigit()
                    }
                }
            }
            .padding(Theme.espaceM)
            .carte()

            VStack(alignment: .leading, spacing: Theme.espaceXS) {
                Text("Résultat des paris conseillés sur les saisons passées").font(Theme.section)
                Text("Mise de 1 € par pari, cote moyenne en ligne, règle actuelle").font(Theme.legende).foregroundColor(.secondary)
                Grid(alignment: .trailing, horizontalSpacing: Theme.espaceM, verticalSpacing: 3) {
                    GridRow {
                        Text("").gridColumnAlignment(.leading)
                        Text("Paris")
                        Text("Réussite")
                        Text("Cote moy.")
                        Text("ROI")
                        Text("IC 95 %")
                    }
                    .font(Theme.legende.weight(.semibold))
                    .foregroundColor(.secondary)
                    ligneSection("Par marché")
                    ForEach(p.parMarche) { ligne($0) }
                    ligneSection("Par espérance")
                    ForEach(p.parEsperance) { ligne($0) }
                    Divider().gridCellUnsizedAxes(.horizontal)
                    ligne(LigneBilan(titre: "Tous", bilan: p.global))
                }
            }
            .padding(Theme.espaceM)
            .carte()
        }
    }

    private func ligneSection(_ titre: String) -> some View {
        GridRow {
            Text(titre)
                .font(Theme.legende.weight(.semibold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .gridCellColumns(6)
        }
    }

    private func ligne(_ l: LigneBilan) -> some View {
        let b = l.bilan
        return GridRow {
            Text(l.titre).gridColumnAlignment(.leading)
            Text("\(b.n)")
            Text(b.n > 0 ? Format.pourcent(b.tauxReussite * 100, decimales: 1, fixe: true) : "—")
            Text(b.n > 0 ? Format.nombre(b.coteMoyenne, decimales: 2, fixe: true) : "—")
            Text(b.n > 0 ? ConseilsView.pourcentSigne(b.roi) : "—")
                .foregroundColor(b.n > 0 ? ConseilsView.couleur(b.verdict) : .secondary)
            Text(b.n > 1 ? ConseilsView.intervalle(b.ic) : "—")
        }
        .font(Theme.corps)
        .monospacedDigit()
    }
}

/// Un conseil : quoi parier, à quelle cote, avec quelle probabilité, et ce que
/// valent historiquement des paris semblables.
private struct CarteConseil: View {
    let pari: Pari
    let match: Match?
    let precision: ResultatPrecision?
    let poids: Double

    /// Probabilité du marché pour ce pari (cotes de référence, marge retirée).
    private var pMarche: Double? {
        guard let match, let p = Cotes.probabilitesMarche(match) else { return nil }
        let index: [Marche: Int] = [.un: 0, .nul: 1, .deux: 2]
        if let (a, b) = pari.marche.jambes, let ia = index[a], let ib = index[b] { return p[ia] + p[ib] }
        return index[pari.marche].map { p[$0] }
    }

    private var preuve: (titre: String, bilan: BilanParis)? { ConseilsView.preuve(pari, precision) }

    private var conseil: (texte: String, verdict: BilanParis.Verdict?) { ConseilsView.recommandation(pari, precision) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.espaceS) {
            HStack(alignment: .firstTextBaseline) {
                Text("J\(pari.journee)" + (dateLisible.map { " · \($0)" } ?? ""))
                    .font(Theme.legende)
                    .foregroundColor(.secondary)
                Spacer()
                let c = conseil
                Label(c.texte, systemImage: c.verdict.map(ConseilsView.icone) ?? "questionmark.circle")
                    .font(Theme.corps.weight(.semibold))
                    .foregroundColor(c.verdict.map(ConseilsView.couleur) ?? .secondary)
            }
            Text("\(pari.domicile) – \(pari.exterieur)")
                .font(Theme.section)
            Text("\(pari.manuel ? "[forcé] " : "")\(pari.marche.titre) à \(Format.nombre(pari.cote, decimales: 2, fixe: true))"
                 + (pari.source.isEmpty ? "" : " · \(pari.source)"))
                .font(Theme.corps.weight(.semibold))

            Grid(alignment: .leading, horizontalSpacing: Theme.espaceS, verticalSpacing: 3) {
                ligne("Probabilité", "\(poids < 1 ? "retenue" : "modèle") \(pct(pari.p))"
                      + (poids < 1 ? " (modèle × \(Format.nombre(poids, decimales: 2, fixe: true)))" : "")
                      + (pMarche.map { " · marché \(pct($0)) (écart \(Format.signe((pari.p - $0) * 100)) pts)" } ?? ""))
                ligne("Espérance", "\(Format.nombre(pari.esperance, decimales: 3, fixe: true)) : "
                      + "\(ConseilsView.pourcentSigne(pari.esperance - 1)) par euro misé si la probabilité retenue est juste")
                if let t = precision?.tranche(pari.p) {
                    ligne("Fiabilité", "annoncé \(Int(t.bas * 100))–\(Int(t.haut * 100)) % → réalisé \(pct(t.observee)) "
                          + "(IC 95 % \(pct(t.ic.bas))–\(pct(t.ic.haut)), \(t.n) cas)")
                }
                if let (titre, b) = preuve {
                    ligne("Historique", "\(titre) : \(b.n) paris, \(pct(b.tauxReussite)) gagnés, ROI "
                          + "\(ConseilsView.pourcentSigne(b.roi)) (IC 95 % \(ConseilsView.intervalle(b.ic)))"
                          + (b.verdict == .incertain && precision?.global.verdict == .perte
                             ? " ; la règle entière perd de façon significative" : ""))
                }
                ligne("Mise", "¼ Kelly \(Format.euro(pari.mises.quartKelly, decimales: true)) "
                      + "(\(Format.nombre(pari.misesPourcent.quartKelly, decimales: 1, fixe: true)) %) · mise fixe "
                      + "\(Format.euro(pari.mises.fixe, decimales: true)) (\(Format.nombre(pari.misesPourcent.fixe, decimales: 1, fixe: true)) %)"
                      + (pari.repartition.map { r in " · répartie \(r.jambeA.rawValue) \(Format.euro(r.miseA, decimales: true)) + "
                          + "\(r.jambeB.rawValue) \(Format.euro(r.miseB, decimales: true))" } ?? ""))
            }
        }
        .padding(Theme.espaceM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .carte()
    }

    private var dateLisible: String? {
        match?.date.flatMap(Jour.depuisISO).map {
            Jour.versDate($0).formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(Format.fr))
        }
    }

    private func pct(_ v: Double) -> String { Format.pourcent(v * 100, decimales: 1, fixe: true) }

    private func ligne(_ titre: String, _ texte: String) -> some View {
        GridRow {
            Text(titre)
                .font(Theme.legende)
                .foregroundColor(.secondary)
            Text(texte)
                .font(Theme.legende)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
