//
//  ProbabilitesView.swift
//  Ligue1
//  © 2026 Stephen O'Donnell, Tanguy Labbe · GNU GPL v3 ou ultérieure (fichier LICENSE).
//
//  Probabilités de classement final (Monte Carlo), recalculées en arrière-plan
//  à chaque score validé.
//
import SwiftUI

struct ProbabilitesView: View {
    @EnvironmentObject var vm: Ligue1ViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.espaceL) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Probabilité de classement final (%)")
                            .font(Theme.titre)
                        statut
                    }
                    Spacer()
                    ConteneurVerre {
                        HStack(alignment: .bottom, spacing: Theme.espaceS) {
                            FiltreMenu(titre: "Simulations", selection: Binding(
                                get: { vm.reglages.simulations },
                                set: { n in vm.modifierReglages { $0.simulations = n } }
                            ), options: Reglages.choixSimulations.map { ($0, $0.formatted(.number.locale(Format.fr))) })
                            Button {
                                vm.lancerSimulation()
                            } label: {
                                Label("Recalculer", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .boutonVerreProeminent()
                            .disabled(vm.simulationEnCours)
                        }
                    }
                }

                if let s = vm.simulation {
                    CarteChaleur(simulation: s, equipes: vm.ligue.equipes)
                } else {
                    EtatVide(icone: "square.grid.3x3", titre: vm.simulationEnCours ? "Calcul en cours…" : "Pas encore calculé",
                             detail: "Le Monte Carlo simule la fin de saison avec les forces actuelles du modèle.")
                }

                Text("Chaque match restant est tiré de la matrice de scores du modèle (forces fixes sur toute la simulation) ; "
                     + "les matchs joués gardent leur score. Départage : points, différence de buts, buts marqués. "
                     + "Équipes classées par nombre de points moyen.")
                    .font(Theme.legende)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
        }
    }

    @ViewBuilder
    private var statut: some View {
        if vm.simulationEnCours {
            Label("Calcul en cours…", systemImage: "hourglass")
                .font(Theme.legende)
                .foregroundColor(.secondary)
        } else if let e = vm.erreurSimulation {
            Label("Erreur simulation : \(e)", systemImage: "exclamationmark.triangle.fill")
                .font(Theme.legende)
                .foregroundColor(Theme.perte)
        } else if let s = vm.simulation {
            Label("Classement final à jour — \(s.simulations.formatted(.number.locale(Format.fr))) saisons simulées, "
                  + "\(vm.ligue.matchsAJouer.count) match\(vm.ligue.matchsAJouer.count > 1 ? "s" : "") à jouer",
                  systemImage: "checkmark.circle.fill")
                .font(Theme.legende)
                .foregroundColor(Theme.gain)
        }
    }
}

/// Carte de chaleur : une ligne par équipe, une colonne par place finale.
private struct CarteChaleur: View {
    let simulation: ResultatSimulation
    let equipes: [String]

    var body: some View {
        let triees = equipes.enumerated().sorted { a, b in
            let pa = simulation.pointsMoyens[a.element] ?? 0, pb = simulation.pointsMoyens[b.element] ?? 0
            return pa != pb ? pa > pb : a.offset < b.offset
        }.map(\.element)
        let n = equipes.count

        Grid(horizontalSpacing: 1, verticalSpacing: 1) {
            GridRow {
                Text("Position finale")
                    .font(Theme.legende.weight(.semibold))
                    .foregroundColor(.secondary)
                    .gridColumnAlignment(.leading)
                ForEach(1...max(n, 1), id: \.self) { p in
                    Text("\(p)")
                        .font(Theme.legende.weight(.semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(triees, id: \.self) { e in
                let probas = simulation.probabilitesPlaces[e] ?? []
                GridRow {
                    HStack(spacing: Theme.espaceS) {
                        EtiquetteEquipe(equipe: e, taille: 18)
                        Text("(\(Format.nombre(simulation.pointsMoyens[e] ?? 0, decimales: 0)) pts)")
                            .foregroundColor(.secondary)
                    }
                    .font(Theme.legende)
                    .frame(minWidth: 230, alignment: .leading)
                    ForEach(0..<n, id: \.self) { i in
                        let v = i < probas.count ? probas[i] : 0
                        Text(v >= 0.005 ? Format.nombre(v, decimales: 2, fixe: true) : "")
                            .font(.system(size: 9.5).monospacedDigit())
                            .foregroundColor(v > 55 ? .white : .black)
                            .frame(minWidth: 34, maxWidth: .infinity, minHeight: 24)
                            .background(Self.couleur(v))
                            .help("\(e) : \(Format.pourcent(v, decimales: 2)) de finir \(i + 1)\(i == 0 ? "er" : "e")")
                    }
                }
            }
        }
        .padding(Theme.espaceM)
        .carte()
    }

    /// Palette « Reds » de matplotlib, de 0 à 100 %.
    private static let palette: [(Double, Double, Double)] = [
        (0xFF, 0xF5, 0xF0), (0xFE, 0xE0, 0xD2), (0xFC, 0xBB, 0xA1), (0xFC, 0x92, 0x72), (0xFB, 0x6A, 0x4A),
        (0xEF, 0x3B, 0x2C), (0xCB, 0x18, 0x1D), (0xA5, 0x0F, 0x15), (0x67, 0x00, 0x0D)
    ]

    static func couleur(_ v: Double) -> Color {
        let t = min(max(v / 100, 0), 1) * Double(palette.count - 1)
        let i = min(Int(t), palette.count - 2)
        let f = t - Double(i)
        let a = palette[i], b = palette[i + 1]
        return Color(.sRGB, red: (a.0 + (b.0 - a.0) * f) / 255, green: (a.1 + (b.1 - a.1) * f) / 255,
                     blue: (a.2 + (b.2 - a.2) * f) / 255, opacity: 1)
    }
}
