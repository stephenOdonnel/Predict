//
//  AnalyseEquipeView.swift
//  Predict
//  © 2026 Stephen O'Donnell, Tanguy Labbe · GNU GPL v3 ou ultérieure (fichier LICENSE).
//
//  Analyse d'une équipe : forme récente, classement journée par journée,
//  bilans à domicile / à l'extérieur / contre le top 9 / contre le bottom 9,
//  calendrier complet.
//
import SwiftUI
import Charts

struct AnalyseEquipeView: View {
    @EnvironmentObject var vm: Ligue1ViewModel
    @State private var choix: String?

    private var equipe: String { choix ?? vm.ligue.equipes.first ?? "" }

    var body: some View {
        let forme = AnalyseEquipe.formeRecente(vm.ligue, equipe)
        let historique = AnalyseEquipe.historiqueRangs(vm.ligue)[equipe] ?? []
        let bilans = AnalyseEquipe.bilans(vm.ligue, equipe)

        ScrollView {
            VStack(alignment: .leading, spacing: Theme.espaceL) {
                HStack(alignment: .bottom, spacing: Theme.espaceM) {
                    Ecusson(equipe: equipe, taille: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(equipe)
                            .font(Theme.titre)
                        if let l = Classements.general(vm.ligue).first(where: { $0.equipe == equipe }), l.joues > 0 {
                            Text("\(l.rang)\(l.rang == 1 ? "er" : "e") · \(l.points) pts · \(l.gagnes) V, \(l.nuls) N, \(l.perdus) D · "
                                 + "\(l.butsPour) buts marqués, \(l.butsContre) encaissés")
                                .font(Theme.legende)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    ConteneurVerre {
                        FiltreMenu(titre: "Équipe", selection: Binding(get: { equipe }, set: { choix = $0 }),
                                   options: vm.ligue.equipes.map { ($0, $0) })
                    }
                }

                VStack(alignment: .leading, spacing: Theme.espaceS) {
                    Text("Forme récente (5 derniers matchs)")
                        .font(Theme.section)
                    if forme.isEmpty {
                        Text("Aucun match joué pour l'instant.")
                            .font(Theme.corps)
                            .foregroundColor(.secondary)
                    } else {
                        HStack(alignment: .top, spacing: Theme.espaceM) {
                            ForEach(forme) { BadgeForme(match: $0) }
                        }
                    }
                }
                .padding(Theme.espaceM)
                .frame(maxWidth: .infinity, alignment: .leading)
                .carte()

                graphiqueRang(historique)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.espaceM), GridItem(.flexible())],
                          spacing: Theme.espaceM) {
                    CamembertBilan(titre: "À domicile", bilan: bilans.domicile)
                    CamembertBilan(titre: "À l'extérieur", bilan: bilans.exterieur)
                    CamembertBilan(titre: "Contre le top 9", bilan: bilans.top9)
                    CamembertBilan(titre: "Contre le bottom 9", bilan: bilans.bottom9)
                }

                calendrier
            }
            .padding()
        }
    }

    // MARK: Classement journée par journée

    private func graphiqueRang(_ historique: [(journee: Int, rang: Int)]) -> some View {
        let n = vm.ligue.equipes.count
        return VStack(alignment: .leading, spacing: Theme.espaceXS) {
            Text("Classement de \(equipe) journée par journée")
                .font(Theme.section)
            if historique.isEmpty {
                Text("Aucun match joué pour l'instant")
                    .font(Theme.corps)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart {
                    ForEach(historique, id: \.journee) { p in
                        LineMark(x: .value("Journée", p.journee), y: .value("Rang", p.rang))
                            .foregroundStyle(Theme.accent)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        PointMark(x: .value("Journée", p.journee), y: .value("Rang", p.rang))
                            .foregroundStyle(Theme.accent)
                            .symbolSize(24)
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false, reversed: true))
                .chartYAxis {
                    AxisMarks(values: Array(stride(from: 1, through: n, by: 2))) { _ in
                        AxisGridLine().foregroundStyle(Theme.piste)
                        AxisValueLabel()
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 12)) { _ in
                        AxisGridLine().foregroundStyle(Theme.piste)
                        AxisValueLabel()
                    }
                }
                .chartXAxisLabel("Journée")
                .chartYAxisLabel("Rang")
                .frame(height: 220)
            }
        }
        .padding(Theme.espaceM)
        .carte()
    }

    // MARK: Calendrier

    private var calendrier: some View {
        VStack(alignment: .leading, spacing: Theme.espaceS) {
            Text("Calendrier complet")
                .font(Theme.section)
            VStack(spacing: 0) {
                HStack(spacing: Theme.espaceS) {
                    Text("J").frame(width: 34, alignment: .trailing)
                    Text("Adversaire").frame(minWidth: 240, maxWidth: .infinity, alignment: .leading)
                    Text("Lieu").frame(width: 80, alignment: .leading)
                    Text("Score").frame(width: 70, alignment: .trailing)
                }
                .font(Theme.legende.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.vertical, 5)
                .padding(.horizontal, Theme.espaceS)
                Divider()
                ForEach(AnalyseEquipe.calendrier(vm.ligue, equipe)) { m in
                    HStack(spacing: Theme.espaceS) {
                        Text("\(m.journee)").frame(width: 34, alignment: .trailing)
                        EtiquetteEquipe(equipe: m.adversaire)
                            .frame(minWidth: 240, maxWidth: .infinity, alignment: .leading)
                        Text(m.aDomicile ? "Domicile" : "Extérieur").frame(width: 80, alignment: .leading)
                        Group {
                            if let p = m.butsPour, let c = m.butsContre {
                                Text("\(p)-\(c)")
                                    .bold()
                                    .foregroundColor(couleur(m.resultat))
                            } else {
                                Text("à venir").foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 70, alignment: .trailing)
                    }
                    .font(Theme.corps)
                    .monospacedDigit()
                    .padding(.vertical, 4)
                    .padding(.horizontal, Theme.espaceS)
                    .background(m.joue ? Theme.accent.opacity(0.06) : .clear,
                                in: RoundedRectangle(cornerRadius: Theme.rayonPetit / 2))
                }
            }
            .padding(Theme.espaceS)
            .carte()
        }
    }

    private func couleur(_ r: ResultatMatch?) -> Color {
        switch r {
        case .victoire?: return Theme.gain
        case .defaite?:  return Theme.perte
        default:         return .primary
        }
    }
}

/// Badge V/N/D d'un match de la forme récente.
private struct BadgeForme: View {
    let match: MatchEquipe

    var body: some View {
        let r = match.resultat ?? .nul
        VStack(spacing: 4) {
            Text(r.rawValue)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(couleur(r), in: Circle())
            Text("J\(match.journee) · \(match.aDomicile ? "dom." : "ext.")")
                .font(.caption2)
                .foregroundColor(.secondary)
            EtiquetteEquipe(equipe: match.adversaire, taille: 16)
                .font(.caption2)
                .frame(maxWidth: 130)
            Text("\(match.butsPour ?? 0)-\(match.butsContre ?? 0)")
                .font(Theme.legende.weight(.semibold))
                .monospacedDigit()
        }
        .frame(minWidth: 90)
    }

    private func couleur(_ r: ResultatMatch) -> Color {
        switch r {
        case .victoire: return Theme.gain
        case .nul:      return Theme.nul
        case .defaite:  return Theme.perte
        }
    }
}

/// Victoires, nuls et défaites d'un sous-ensemble de matchs, avec les moyennes par match.
private struct CamembertBilan: View {
    let titre: String
    let bilan: BilanPartiel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.espaceXS) {
            Text("\(titre)  (\(bilan.joues) match\(bilan.joues > 1 ? "s" : ""))")
                .font(Theme.section)
            if bilan.joues == 0 {
                Text("Aucun match")
                    .font(Theme.corps)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                Text("\(Format.nombre(bilan.pointsParMatch, decimales: 2, fixe: true)) pts/m · "
                     + "\(Format.nombre(bilan.butsPourParMatch, decimales: 2, fixe: true)) bm/m · "
                     + "\(Format.nombre(bilan.butsContreParMatch, decimales: 2, fixe: true)) bc/m")
                    .font(Theme.legende)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                HStack(spacing: Theme.espaceM) {
                    Chart(parts, id: \.nom) { p in
                        SectorMark(angle: .value("Matchs", p.valeur), innerRadius: .ratio(0.5), angularInset: 1.5)
                            .foregroundStyle(p.couleur)
                    }
                    .frame(width: 140, height: 140)
                    VStack(alignment: .leading, spacing: Theme.espaceXS) {
                        ForEach(parts, id: \.nom) { p in
                            HStack(spacing: 6) {
                                Circle().fill(p.couleur).frame(width: 8, height: 8)
                                Text("\(p.nom) : \(p.valeur)")
                                Text("(\(Format.pourcent(Double(p.valeur) / Double(bilan.joues) * 100, decimales: 0)))")
                                    .foregroundColor(.secondary)
                            }
                            .font(Theme.corps)
                            .monospacedDigit()
                        }
                    }
                }
            }
        }
        .padding(Theme.espaceM)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .carte()
    }

    private var parts: [(nom: String, valeur: Int, couleur: Color)] {
        [("Victoires", bilan.gagnes, Theme.gain), ("Nuls", bilan.nuls, Theme.nul), ("Défaites", bilan.perdus, Theme.perte)]
            .filter { $0.valeur > 0 }
    }
}
