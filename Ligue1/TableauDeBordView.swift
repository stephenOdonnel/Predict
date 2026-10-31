//
//  TableauDeBordView.swift
//  Ligue1
//  © 2026 Stephen O'Donnell, Tanguy Labbe · GNU GPL v3 ou ultérieure (fichier LICENSE).
//
//  Vue d'ensemble : prochaine journée, paris conseillés, classement et fin de
//  saison simulée, points à surveiller.
//
import SwiftUI

struct TableauDeBordView: View {
    @EnvironmentObject var vm: Ligue1ViewModel
    /// Section de la barre latérale, pour les liens vers le détail.
    @Binding var selection: String?
    @AppStorage(MenuItem.cleMasquees) private var sectionsMasquees = ""

    /// Première journée qui reste à jouer, comme Journées & cotes.
    private var prochaine: Int? { vm.ligue.matchsAJouer.map(\.journee).min() }

    var body: some View {
        let r = vm.resultatParis
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.espaceL) {
                enTete
                chiffresCles(r)
                carteJournee
                HStack(alignment: .top, spacing: Theme.espaceM) {
                    carteConseils(r)
                    carteClassement
                }
                alertes
                Text("Simulation à but d'étude : aucun résultat passé ne garantit un gain futur. Ne misez que ce que "
                     + "vous pouvez perdre ; aide : Joueurs Info Service, 09 74 75 13 13.")
                    .font(Theme.legende)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
        }
        // Mesure en cache : instantanée tant que l'historique et les paramètres ne changent pas.
        .onAppear { vm.lancerPrecision() }
        .onChange(of: vm.reglages) { _, _ in vm.lancerPrecision() }
        .onChange(of: vm.calibrationEnCours) { _, enCours in
            if !enCours { vm.lancerPrecision() }
        }
    }

    // MARK: En-tête

    private var enTete: some View {
        VStack(alignment: .leading, spacing: Theme.espaceS) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Saison \(vm.ligue.season ?? "")")
                    .font(Theme.titre)
                Text("\(vm.ligue.matchsJoues.count) matchs joués sur \(vm.ligue.matches.count). Chaque semaine, "
                     + "« Mettre à jour en ligne » charge scores, calendrier et cotes.")
                    .font(Theme.legende)
                    .foregroundColor(.secondary)
            }
            BoutonImportCSV()
        }
    }

    // MARK: Chiffres clés

    private func chiffresCles(_ r: ResultatParis) -> some View {
        let classement = Classements.general(vm.ligue)
        let gain = r.gainsPourcent.quartKelly

        return HStack(spacing: Theme.espaceM) {
            TuileChiffre(titre: "Prochaine journée",
                         valeur: prochaine.map { "J\($0) / \(vm.ligue.nJournees)" } ?? "Terminée",
                         detail: prochaine.map(detailJournee) ?? "tous les matchs sont joués",
                         icone: "calendar")
            if let premier = classement.first, !vm.ligue.matchsJoues.isEmpty {
                TuileChiffre(titre: "En tête", valeur: premier.equipe,
                             detail: detailLeader(premier, classement.dropFirst().first),
                             icone: "trophy.fill")
            } else {
                TuileChiffre(titre: "En tête", valeur: "—", detail: "aucun match joué", icone: "trophy.fill")
            }
            TuileChiffre(titre: "Bankroll simulée ¼ Kelly", valeur: Format.euro(r.bankrolls.quartKelly),
                         detail: "\(Format.signe(gain)) % sur l'argent engagé, \(r.paris.count) paris joués",
                         icone: "banknote",
                         couleurValeur: gain > 0 ? Theme.gain : gain < 0 ? Theme.perte : .primary)
            TuileChiffre(titre: "Paris conseillés", valeur: "\(r.enAttente.count)",
                         detail: detailPrecision, icone: "lightbulb")
        }
        // Tuiles alignées sur la plus haute.
        .fixedSize(horizontal: false, vertical: true)
    }

    private func detailJournee(_ j: Int) -> String {
        let restants = vm.ligue.matchs(journee: j).filter { !$0.joue }
        let debut = restants.compactMap { $0.date.flatMap(Jour.depuisISO) }.min()
        return "\(restants.count) match\(restants.count > 1 ? "s" : "") à jouer"
            + (debut.map { ", dès le \(Self.date($0))" } ?? ", dates à venir")
    }

    private func detailLeader(_ premier: LigneClassement, _ second: LigneClassement?) -> String {
        guard let second else { return "\(premier.points) pts" }
        let ecart = premier.points - second.points
        return "\(premier.points) pts, "
            + (ecart > 0 ? "\(ecart) d'avance sur \(second.equipe)" : "à égalité de points avec \(second.equipe)")
    }

    private var detailPrecision: String {
        if let p = vm.precision {
            return "règle actuelle : ROI \(ConseilsView.pourcentSigne(p.global.roi)) sur \(p.saisons.count) saisons passées"
        }
        return vm.precisionEnCours ? "mesure de la précision…" : "précision inconnue"
    }

    // MARK: Prochaine journée

    private var carteJournee: some View {
        VStack(alignment: .leading, spacing: Theme.espaceS) {
            titreCarte(prochaine.map { "Journée \($0)" } ?? "Journées", section: "journees", lien: "Scores et cotes")
            if let j = prochaine {
                let matchs = vm.ligue.matchs(journee: j)
                    .sorted { ($0.date ?? "9999", $0.domicile) < ($1.date ?? "9999", $1.domicile) }
                HStack(spacing: Theme.espaceS) {
                    Spacer()
                    ForEach(["1", "N", "2"], id: \.self) { Text($0).frame(width: 48, alignment: .trailing) }
                }
                .font(Theme.legende.weight(.semibold))
                .foregroundColor(.secondary)
                ForEach(matchs) { ligneMatch($0) }
                Text("Probabilités du modèle avant le match ; la plus forte en couleur.")
                    .font(Theme.legende)
                    .foregroundColor(.secondary)
            } else {
                Text("Saison terminée : tous les matchs sont joués.")
                    .font(Theme.corps)
                    .foregroundColor(.secondary)
            }
        }
        .padding(Theme.espaceM)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .carte()
    }

    private func ligneMatch(_ m: Match) -> some View {
        let p = m.joue ? nil : vm.modele?.probas(m.domicile, m.exterieur).triplet
        let favori = p.flatMap { v in v.indices.max { v[$0] < v[$1] } }

        return HStack(spacing: Theme.espaceS) {
            Text(m.date.flatMap(Jour.depuisISO).map(Self.date) ?? "à fixer")
                .foregroundColor(.secondary)
                .frame(width: 96, alignment: .leading)
            EtiquetteEquipe(equipe: m.domicile, taille: 18, inverse: true)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Group {
                if let h = m.butsDomicile, let a = m.butsExterieur {
                    Text("\(h) – \(a)").bold()
                } else {
                    Text("–").foregroundColor(.secondary)
                }
            }
            .frame(width: 48)
            EtiquetteEquipe(equipe: m.exterieur, taille: 18)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(0..<3, id: \.self) { i in
                Text(p.map { Format.pourcent($0[i] * 100, decimales: 0) } ?? "")
                    .fontWeight(favori == i ? .semibold : .regular)
                    .foregroundColor(favori == i ? Theme.accent : .secondary)
                    .frame(width: 48, alignment: .trailing)
            }
        }
        .font(Theme.corps)
        .monospacedDigit()
    }

    // MARK: Paris conseillés

    private func carteConseils(_ r: ResultatParis) -> some View {
        let conseils = r.enAttente.sorted {
            ($0.journee, $0.domicile, $0.marche.rawValue) < ($1.journee, $1.domicile, $1.marche.rawValue)
        }
        let affiches = Array(conseils.prefix(6))

        return VStack(alignment: .leading, spacing: Theme.espaceS) {
            titreCarte("Paris conseillés", section: "conseils", lien: "Détail et précision")
            if let p = vm.precision {
                Label("Règle actuelle sur \(p.saisons.count) saisons passées : ROI "
                      + "\(ConseilsView.pourcentSigne(p.global.roi)) (IC 95 % \(ConseilsView.intervalle(p.global.ic)))",
                      systemImage: ConseilsView.icone(p.global.verdict))
                    .font(Theme.legende)
                    .foregroundColor(ConseilsView.couleur(p.global.verdict))
                    .fixedSize(horizontal: false, vertical: true)
            } else if vm.precisionEnCours {
                HStack(spacing: Theme.espaceS) {
                    ProgressView().controlSize(.small)
                    Text("Mesure de la précision sur les saisons passées…")
                }
                .font(Theme.legende)
            }
            if affiches.isEmpty {
                Text("Aucun match à venir ne passe le seuil d'espérance avec les cotes connues.")
                    .font(Theme.corps)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(affiches) { ligneConseil($0) }
                if conseils.count > affiches.count {
                    Text("et \(conseils.count - affiches.count) autre\(conseils.count - affiches.count > 1 ? "s" : "")…")
                        .font(Theme.legende)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(Theme.espaceM)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .carte()
    }

    private func ligneConseil(_ p: Pari) -> some View {
        let c = ConseilsView.recommandation(p, vm.precision)

        return VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.espaceS) {
                Text("J\(p.journee) · \(p.domicile) – \(p.exterieur)")
                    .font(Theme.corps.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Label(c.texte, systemImage: c.verdict.map(ConseilsView.icone) ?? "questionmark.circle")
                    .font(Theme.legende.weight(.semibold))
                    .foregroundColor(c.verdict.map(ConseilsView.couleur) ?? .secondary)
                    .fixedSize()
            }
            Text("\(p.manuel ? "[forcé] " : "")\(p.marche.titre) à \(Format.nombre(p.cote, decimales: 2, fixe: true))"
                 + (p.source.isEmpty ? "" : " · \(p.source)")
                 + " · ¼ Kelly \(Format.euro(p.mises.quartKelly, decimales: true))")
                .font(Theme.legende)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }

    // MARK: Classement

    private var carteClassement: some View {
        let lignes = Classements.general(vm.ligue)
        let n = lignes.count
        // Haut et bas du tableau ; le milieu est dans Classements.
        let affichees = n > 9 ? Array(lignes.prefix(6)) + Array(lignes.suffix(3)) : lignes

        return VStack(alignment: .leading, spacing: Theme.espaceXS) {
            titreCarte("Classement", section: "classements", lien: "Tous les classements")
                .padding(.bottom, Theme.espaceXS)
            HStack(spacing: Theme.espaceS) {
                Text("").frame(width: 24)
                Text("Équipe").frame(maxWidth: .infinity, alignment: .leading)
                ForEach(["Pts", "Titre", "Top 3", "3 der."], id: \.self) {
                    Text($0).frame(width: 46, alignment: .trailing)
                }
            }
            .font(Theme.legende.weight(.semibold))
            .foregroundColor(.secondary)
            ForEach(affichees) { l in
                if n > 9, l.rang == n - 2 {
                    Text("…").foregroundColor(.secondary).frame(width: 24, alignment: .trailing)
                }
                ligneClassement(l, sur: n)
            }
            Group {
                if let s = vm.simulation {
                    Text("Titre, top 3 et 3 derniers : classement final simulé sur "
                         + "\(s.simulations.formatted(.number.locale(Format.fr))) saisons.")
                } else {
                    Text(vm.simulationEnCours ? "Simulation de la fin de saison…" : "Fin de saison pas encore simulée (⌘R).")
                }
            }
            .font(Theme.legende)
            .foregroundColor(.secondary)
            .padding(.top, Theme.espaceXS)
        }
        .padding(Theme.espaceM)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .carte()
    }

    private func ligneClassement(_ l: LigneClassement, sur n: Int) -> some View {
        let places = vm.simulation?.probabilitesPlaces[l.equipe]
        let chances: [Double]? = places.map { p in
            [p.first ?? 0, p.prefix(3).reduce(0, +), p.suffix(3).reduce(0, +)]
        }

        return HStack(spacing: Theme.espaceS) {
            Text("\(l.rang)")
                .bold()
                .foregroundColor(Self.zone(l.rang, sur: n))
                .frame(width: 24, alignment: .trailing)
            EtiquetteEquipe(equipe: l.equipe, taille: 18)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(l.points)")
                .fontWeight(.semibold)
                .frame(width: 46, alignment: .trailing)
            ForEach(0..<3, id: \.self) { i in
                Text(chances.map { Self.chance($0[i]) } ?? "—")
                    .foregroundColor(.secondary)
                    .frame(width: 46, alignment: .trailing)
            }
        }
        .font(Theme.corps)
        .monospacedDigit()
    }

    /// Podium, places européennes, bas de tableau : mêmes couleurs que Classements.
    private static func zone(_ rang: Int, sur n: Int) -> Color? {
        if rang <= 3 { return .green }
        if rang <= 6 { return .blue }
        if rang >= n - 2 { return .red }
        return nil
    }

    /// Pourcentage arrondi ; une chance non nulle n'est jamais affichée « 0 % ».
    private static func chance(_ v: Double) -> String {
        if v > 0 && v < 0.5 { return "< 1 %" }
        return Format.pourcent(v, decimales: 0)
    }

    // MARK: À surveiller

    @ViewBuilder
    private var alertes: some View {
        let lignes = alertesTexte
        if !lignes.isEmpty {
            Bandeau(titre: "À surveiller", lignes: lignes)
        }
    }

    private var alertesTexte: [String] {
        var lignes: [String] = []
        if vm.reglages.parametresModele == nil, !vm.calibrationEnCours {
            lignes.append("Modèle non calibré : il faut au moins deux saisons d'historique. "
                          + "« Mettre à jour en ligne » charge les 10 dernières saisons.")
        }
        let aujourdhui = Jour.depuisDate(Date())
        let enRetard = vm.ligue.matchsAJouer.filter { ($0.date.flatMap(Jour.depuisISO) ?? .max) < aujourdhui }.count
        if enRetard > 0 {
            lignes.append("\(enRetard) match\(enRetard > 1 ? "s" : "") daté\(enRetard > 1 ? "s" : "") d'avant aujourd'hui "
                          + "sans score : « Mettre à jour en ligne » récupère les résultats (ou le match a été reporté).")
        }
        if let j = prochaine {
            let sansCote = vm.ligue.matchs(journee: j).filter { !$0.joue && $0.livres.isEmpty }.count
            if sansCote > 0 {
                lignes.append("\(sansCote) match\(sansCote > 1 ? "s" : "") de la J\(j) sans cote Winamax, Unibet, Bwin "
                              + "ou Betclic : les conseils y prennent la cote moyenne en ligne, indicative. Saisissez-les "
                              + "dans Journées & cotes, ou ajoutez une clé The Odds API (Paramètres › Saison).")
            }
        }
        if let p = vm.precision {
            if p.global.verdict == .perte {
                lignes.append("La règle de paris actuelle a perdu de l'argent sur les saisons passées : "
                              + "le marché reste plus précis que le modèle.")
            }
            if p.sansOuverture > 0 {
                lignes.append("\(p.sansOuverture) match(s) de l'historique sans cotes d'ouverture : la précision des "
                              + "conseils est flattée. « Mettre à jour en ligne » recharge ces saisons.")
            }
        }
        if let e = vm.erreurSimulation {
            lignes.append("Classement final simulé : \(e.lowercased()). ⌘R pour relancer.")
        }
        return lignes
    }

    // MARK: Outils

    /// Titre de carte et lien vers la section détaillée, sauf si elle est masquée.
    private func titreCarte(_ titre: String, section: String, lien: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titre)
                .font(Theme.section)
            Spacer()
            if !MenuItem.masquees(sectionsMasquees).contains(section) {
                Button {
                    selection = section
                } label: {
                    HStack(spacing: 2) {
                        Text(lien)
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(.link)
                .font(Theme.legende)
            }
        }
    }

    private static func date(_ jour: Int) -> String {
        Jour.versDate(jour).formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(Format.fr))
    }
}
