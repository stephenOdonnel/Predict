//
//  EnsembleView.swift
//  Predict
//  © 2026 Stephen O'Donnell, Tanguy Labbe · GNU GPL v3 ou ultérieure (fichier LICENSE).
//
//  Vue d'ensemble des cinq championnats : avancement de la saison et résultat de la
//  simulation de paris de chacun, total cumulé, et mise à jour de tous en une fois.
//
//  Chaque championnat garde sa propre simulation de bankroll (ses journées, ses
//  réglages, ses dépôts) ; le total est la somme des cinq. Les chiffres d'un
//  championnat sont ceux de sa dernière ouverture.
//
import SwiftUI

struct EnsembleView: View {
    @EnvironmentObject var vm: Ligue1ViewModel
    @Binding var selection: String?
    @State private var methode: MethodeMise = .fixe

    private func bankroll(_ r: ResumeChampionnat) -> Double {
        switch methode {
        case .fixe:       return r.fixe
        case .kelly:      return r.kelly
        case .demiKelly:  return r.demiKelly
        case .quartKelly: return r.quartKelly
        }
    }

    private var connus: [(championnat: Championnat, resume: ResumeChampionnat)] {
        Championnat.allCases.compactMap { c in vm.resumes[c.rawValue].map { (c, $0) } }
    }

    private var departTotal: Double { connus.reduce(0) { $0 + $1.resume.bankrollDepart } }
    private var actuelTotal: Double { connus.reduce(0) { $0 + bankroll($1.resume) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.espaceM) {
                Text("Vue d'ensemble")
                    .font(Theme.titre)

                HStack(spacing: Theme.espaceM) {
                    Button {
                        vm.mettreAJourTout()
                    } label: {
                        Label(vm.majGlobaleEnCours ? "Mise à jour…" : "Tout mettre à jour",
                              systemImage: "arrow.triangle.2.circlepath")
                    }
                    .boutonVerreProeminent()
                    .disabled(vm.occupe || vm.majGlobaleEnCours || vm.blocageIntegrite != nil)
                    .help("Télécharge les CSV, les cotes (si une clé The Odds API est enregistrée) et les xG "
                          + "des cinq championnats, l'un après l'autre.")

                    if vm.majGlobaleEnCours {
                        ProgressView().controlSize(.small)
                        Text(vm.majGlobaleTexte ?? "").font(Theme.corps).foregroundColor(.secondary)
                    }

                    Spacer()

                    Picker("Méthode de mise", selection: $methode) {
                        ForEach(MethodeMise.allCases) { m in Text(m.titre).tag(m) }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                }

                if !vm.rapportsMajGlobale.isEmpty {
                    Bandeau(titre: "Dernière mise à jour", lignes: vm.rapportsMajGlobale, icone: "checkmark.circle.fill", couleur: .green)
                }

                VStack(spacing: 0) {
                    ForEach(Championnat.allCases) { c in
                        ligne(c)
                        Divider()
                    }
                    totalLigne
                }
                .carte()

                Text("Ici, chaque championnat est simulé séparément, avec la bankroll de départ de ses propres "
                     + "réglages ; le total additionne les cinq. Pour une seule bankroll commune, rejouée semaine "
                     + "par semaine sur les cinq championnats : Simulation des paris › Tous les championnats.")
                    .font(Theme.legende)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Theme.espaceL)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func ligne(_ c: Championnat) -> some View {
        HStack(spacing: Theme.espaceM) {
            Text("\(c.drapeau) \(c.nom)")
                .font(Theme.section)
                .frame(width: 170, alignment: .leading)

            if let r = vm.resumes[c.rawValue] {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Saison \(r.saison)")
                    Text("\(r.matchsJoues) / \(r.matchsTotal) matchs joués")
                        .font(Theme.legende).foregroundColor(.secondary)
                }
                .frame(width: 170, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(r.parisRegles) pari\(r.parisRegles > 1 ? "s" : "") réglé\(r.parisRegles > 1 ? "s" : "")")
                    Text("\(r.parisEnAttente) en attente")
                        .font(Theme.legende).foregroundColor(.secondary)
                }
                .frame(width: 140, alignment: .leading)

                Spacer()

                let b = bankroll(r)
                let gain = r.bankrollDepart > 0 ? (b / r.bankrollDepart - 1) * 100 : 0
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Format.euro(b)).monospacedDigit()
                    Text(Format.signe(gain) + " %")
                        .font(Theme.legende)
                        .foregroundColor(gain >= 0 ? Theme.gain : Theme.perte)
                }
            } else {
                Text("Pas encore chargé")
                    .font(Theme.corps)
                    .foregroundColor(.secondary)
                Spacer()
            }

            Button(c == vm.championnat ? "Affiché" : "Ouvrir") {
                vm.changerChampionnat(c)
                selection = MenuItem.obligatoire
            }
            .disabled(c == vm.championnat || vm.occupe || vm.majGlobaleEnCours)
        }
        .font(Theme.corps)
        .padding(Theme.espaceM)
    }

    private var totalLigne: some View {
        let gain = departTotal > 0 ? (actuelTotal / departTotal - 1) * 100 : 0
        return HStack {
            Text("Total")
                .font(Theme.section)
            Spacer()
            Text("départ \(Format.euro(departTotal))")
                .font(Theme.corps)
                .foregroundColor(.secondary)
            VStack(alignment: .trailing, spacing: 2) {
                Text(Format.euro(actuelTotal)).monospacedDigit()
                Text(Format.signe(gain) + " %")
                    .font(Theme.legende)
                    .foregroundColor(gain >= 0 ? Theme.gain : Theme.perte)
            }
        }
        .font(Theme.corps)
        .padding(Theme.espaceM)
    }
}
