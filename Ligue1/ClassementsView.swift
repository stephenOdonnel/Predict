//
//  ClassementsView.swift
//  Ligue1
//  © 2026 Stephen O'Donnell, Tanguy Labbe · GNU GPL v3 ou ultérieure (fichier LICENSE).
//
//  Classements selon le critère choisi : général, domicile, extérieur, contre
//  le top 9 / bottom 9 (d'après le classement actuel), aux xPoints.
//
import SwiftUI

struct ClassementsView: View {
    @EnvironmentObject var vm: Ligue1ViewModel
    @State private var critere: CritereClassement = .general

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.espaceL) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(critere.titre)
                            .font(Theme.titre)
                        Text(sousTitre)
                            .font(Theme.legende)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    ConteneurVerre {
                        FiltreMenu(titre: "Critère", selection: $critere,
                                   options: CritereClassement.allCases.map { ($0, $0.titre) })
                    }
                }

                if critere == .xPoints {
                    tableauXPoints(Classements.xPoints(vm.ligue))
                } else {
                    tableau(lignes)
                }

                legende
            }
            .padding()
        }
    }

    private var sousTitre: String {
        switch critere {
        case .general:   return "Points, puis différence de buts, puis buts marqués"
        case .domicile:  return "Matchs joués à domicile uniquement"
        case .exterieur: return "Matchs joués à l'extérieur uniquement"
        case .top9:      return "Matchs contre les 9 premiers du classement actuel"
        case .bottom9:   return "Matchs contre les équipes classées 10e ou au-delà"
        case .xPoints:   return "Points « attendus » d'après les xG (le score sert de repli sans xG) : qui sur- ou sous-performe"
        }
    }

    private var lignes: [LigneClassement] {
        switch critere {
        case .general:   return Classements.general(vm.ligue)
        case .domicile:  return Classements.domicile(vm.ligue)
        case .exterieur: return Classements.exterieur(vm.ligue)
        case .top9:      return Classements.contreGroupe(vm.ligue, top9: true)
        case .bottom9:   return Classements.contreGroupe(vm.ligue, top9: false)
        case .xPoints:   return []
        }
    }

    /// Podium, places européennes, relégation.
    private func zone(_ rang: Int, sur n: Int) -> Color? {
        if rang <= 3 { return .green }
        if rang <= 6 { return .blue }
        if rang >= n - 2 { return .red }
        return nil
    }

    /// Colonnes : rang, équipe (souple), puis chiffres alignés à droite.
    private func ligne(_ cellules: [String], largeurs: [CGFloat], rang: String, equipe: String?, gras: Set<Int> = [],
                       couleurs: [Int: Color] = [:]) -> some View {
        HStack(spacing: Theme.espaceS) {
            Text(rang)
                .bold()
                .frame(width: 28, alignment: .trailing)
            Group {
                if let equipe { EtiquetteEquipe(equipe: equipe) } else { Text("Équipe") }
            }
            .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)
            ForEach(Array(cellules.enumerated()), id: \.offset) { i, texte in
                Text(texte)
                    .fontWeight(gras.contains(i) ? .semibold : .regular)
                    .foregroundColor(couleurs[i])
                    .frame(width: largeurs[i], alignment: .trailing)
            }
        }
        .monospacedDigit()
        .padding(.vertical, 5)
        .padding(.horizontal, Theme.espaceS)
    }

    private func tableau(_ lignes: [LigneClassement]) -> some View {
        let largeurs: [CGFloat] = [36, 36, 36, 36, 44, 44, 48, 48]
        return VStack(spacing: 0) {
            ligne(["J", "G", "N", "P", "BP", "BC", "Diff", "Pts"], largeurs: largeurs, rang: "#", equipe: nil)
                .font(Theme.legende.weight(.semibold))
                .foregroundColor(.secondary)
            Divider()
            ForEach(lignes) { l in
                ligne(["\(l.joues)", "\(l.gagnes)", "\(l.nuls)", "\(l.perdus)", "\(l.butsPour)", "\(l.butsContre)",
                       (l.difference > 0 ? "+" : "") + "\(l.difference)", "\(l.points)"],
                      largeurs: largeurs, rang: "\(l.rang)", equipe: l.equipe, gras: [7])
                    .font(Theme.corps)
                    .background((zone(l.rang, sur: lignes.count) ?? .clear).opacity(0.12),
                                in: RoundedRectangle(cornerRadius: Theme.rayonPetit / 2))
            }
        }
        .padding(Theme.espaceS)
        .carte()
    }

    private func tableauXPoints(_ lignes: [LigneXPoints]) -> some View {
        let largeurs: [CGFloat] = [36, 90, 90, 60, 60, 70]
        return VStack(spacing: 0) {
            ligne(["J", "xG marqués", "xG concédés", "xDiff", "xPts", "Pts réels"], largeurs: largeurs, rang: "#", equipe: nil)
                .font(Theme.legende.weight(.semibold))
                .foregroundColor(.secondary)
            Divider()
            ForEach(lignes) { l in
                ligne(["\(l.joues)", Format.nombre(l.xgPour, decimales: 1, fixe: true),
                       Format.nombre(l.xgContre, decimales: 1, fixe: true), Format.signe(l.xgDifference),
                       Format.nombre(l.xPoints, decimales: 1, fixe: true), "\(l.pointsReels)"],
                      largeurs: largeurs, rang: "\(l.rang)", equipe: l.equipe, gras: [4],
                      couleurs: [5: Double(l.pointsReels) >= l.xPoints ? Theme.gain : Theme.perte])
                    .font(Theme.corps)
                    .background((zone(l.rang, sur: lignes.count) ?? .clear).opacity(0.12),
                                in: RoundedRectangle(cornerRadius: Theme.rayonPetit / 2))
                    .help(Double(l.pointsReels) >= l.xPoints ? "Points réels au-dessus des xPoints : sur-performe ses xG"
                                                              : "Points réels sous les xPoints : sous-performe ses xG")
            }
        }
        .padding(Theme.espaceS)
        .carte()
    }

    private var legende: some View {
        HStack(spacing: Theme.espaceM) {
            pastille(.green, "Podium (1–3)")
            pastille(.blue, "4–6")
            pastille(.red, "Trois derniers")
            Spacer()
            Text("Égalité parfaite : points, différence de buts, buts marqués — sans mini-championnat des confrontations directes.")
                .font(Theme.legende)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func pastille(_ couleur: Color, _ texte: String) -> some View {
        Label {
            Text(texte)
        } icon: {
            RoundedRectangle(cornerRadius: 3)
                .fill(couleur.opacity(0.35))
                .frame(width: 14, height: 10)
        }
        .font(Theme.legende)
        .foregroundColor(.secondary)
    }
}
