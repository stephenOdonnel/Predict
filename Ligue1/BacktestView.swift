//
//  BacktestView.swift
//  Ligue1
//  © 2026 Stephen O'Donnell, Tanguy Labbe · GNU GPL v3 ou ultérieure (fichier LICENSE).
//
//  Précision walk-forward du modèle (log-loss, RPS, Brier) comparée au
//  consensus des bookmakers, et courbe de fiabilité. Calibration des
//  hyperparamètres sur l'historique importé. Calculs à la demande, en
//  arrière-plan.
//
import SwiftUI
import Charts

struct BacktestView: View {
    @EnvironmentObject var vm: Ligue1ViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.espaceL) {
                HStack(spacing: Theme.espaceM) {
                    Button {
                        vm.lancerBacktest()
                    } label: {
                        Label(vm.backtestEnCours ? "Backtest en cours…" : "Lancer le backtest",
                              systemImage: vm.backtestEnCours ? "hourglass" : "play.fill")
                    }
                    .boutonVerreProeminent()
                    .disabled(vm.backtestEnCours)
                    statut
                    Spacer()
                }

                Text("Pour chaque journée, le modèle est réajusté avec uniquement ce qui était connu avant elle, puis "
                     + "prédit ses matchs : aucune fuite d'information. Tout est recalculé avec le code actuel, "
                     + "indépendamment des probabilités figées. Comparaison au marché (marge retirée) "
                     + "sur exactement les mêmes matchs. Plus bas = meilleur (log-loss, RPS, Brier). β = part des buts "
                     + "attendus implicites des cotes dans les données du modèle (réglage actuel : "
                     + "\(Format.nombre(vm.reglages.parametresEnService.marketAlpha, decimales: 2, fixe: true))). "
                     + "L'historique importé fait partie des données. Marché = cotes de référence du CSV (clôture "
                     + "Pinnacle de préférence), sinon bookmakers saisis. Poids modèle optimal = poids du "
                     + "modèle quand on le mélange aux cotes du match lui-même : 0 signifie qu'il n'apporte aucune "
                     + "information que les bookmakers n'ont pas déjà. Jugez un réglage sur ce tableau, pas sur le bilan "
                     + "des paris, bien trop bruité sur quelques centaines de paris.")
                    .font(Theme.legende)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let b = vm.backtest {
                    tableau(b)
                    Text("\(b.n) matchs évalués (joués, avec cotes, hors forfait) — nuls réels : "
                         + "\(Format.pourcent(b.nulsObserves * 100, decimales: 1, fixe: true)). "
                         + "Moitiés : J1–\(b.moitie) / J\(b.moitie + 1)–\(b.nJournees).")
                        .font(Theme.corps)
                    fiabilite(b)
                } else if !vm.backtestCalcule {
                    EtatVide(icone: "checkmark.seal", titre: "Backtest non lancé",
                             detail: "Quelques dizaines d'ajustements du modèle : comptez une seconde environ.")
                }

                Divider()
                sectionCalibration
            }
            .padding()
        }
    }

    @ViewBuilder
    private var statut: some View {
        if vm.backtestEnCours {
            ProgressView().controlSize(.small)
        } else if vm.backtestCalcule {
            if vm.backtest == nil {
                Label("Aucun match joué avec cotes : rien à évaluer.", systemImage: "exclamationmark.triangle.fill")
                    .font(Theme.legende)
                    .foregroundColor(Theme.perte)
            } else {
                Label("Backtest à jour (à relancer après modification des scores ou des cotes)",
                      systemImage: "checkmark.circle.fill")
                    .font(Theme.legende)
                    .foregroundColor(Theme.gain)
            }
        }
    }

    private static let titres = ["Log-loss", "LL 1re moitié", "LL 2e moitié", "RPS", "Brier", "Nuls prédits", "Poids modèle optimal"]

    private func tableau(_ b: ResultatBacktest) -> some View {
        let meilleure = b.lignes.map(\.scores.logLoss).min() ?? 0
        func f(_ v: Double?) -> String { v.map { Format.nombre($0, decimales: 4, fixe: true) } ?? "—" }

        return VStack(spacing: 0) {
            HStack(spacing: Theme.espaceS) {
                Text("Prévision").frame(minWidth: 300, maxWidth: .infinity, alignment: .leading)
                ForEach(Self.titres, id: \.self) { Text($0).frame(width: 92, alignment: .trailing) }
            }
            .font(Theme.legende.weight(.semibold))
            .foregroundColor(.secondary)
            .padding(.vertical, 6)
            .padding(.horizontal, Theme.espaceS)
            Divider()
            ForEach(b.lignes) { l in
                HStack(spacing: Theme.espaceS) {
                    Text(l.libelle + (l.reglageActuel ? "  ← réglage actuel" : ""))
                        .frame(minWidth: 300, maxWidth: .infinity, alignment: .leading)
                    Text(f(l.scores.logLoss))
                        .fontWeight(.semibold)
                        .foregroundColor(l.scores.logLoss == meilleure ? Theme.gain : .primary)
                        .frame(width: 92, alignment: .trailing)
                    Text(f(l.logLossMoitie1)).frame(width: 92, alignment: .trailing)
                    Text(f(l.logLossMoitie2)).frame(width: 92, alignment: .trailing)
                    Text(f(l.scores.rps)).frame(width: 92, alignment: .trailing)
                    Text(f(l.scores.brier)).frame(width: 92, alignment: .trailing)
                    Text(Format.pourcent(l.nulsPredits * 100, decimales: 1, fixe: true)).frame(width: 92, alignment: .trailing)
                    Text(l.poidsModeleOptimal.map { Format.nombre($0, decimales: 1, fixe: true) } ?? "—")
                        .frame(width: 92, alignment: .trailing)
                }
                .font(Theme.corps)
                .monospacedDigit()
                .padding(.vertical, 5)
                .padding(.horizontal, Theme.espaceS)
                .background(l.reglageActuel ? Theme.accent.opacity(0.08) : .clear,
                            in: RoundedRectangle(cornerRadius: Theme.rayonPetit / 2))
            }
        }
        .padding(Theme.espaceS)
        .carte()
    }

    private func fiabilite(_ b: ResultatBacktest) -> some View {
        let couleurs: [Color] = [.orange, Theme.accent]
        return VStack(alignment: .leading, spacing: Theme.espaceXS) {
            Text("Courbe de fiabilité (1/N/2 regroupés, tranches de 10 %)")
                .font(Theme.section)
            Chart {
                LineMark(x: .value("Prédite", 0.0), y: .value("Observée", 0.0), series: .value("Série", "Parfait"))
                    .foregroundStyle(Color.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                LineMark(x: .value("Prédite", 1.0), y: .value("Observée", 1.0), series: .value("Série", "Parfait"))
                    .foregroundStyle(Color.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                ForEach(Array(b.calibration.enumerated()), id: \.offset) { i, courbe in
                    ForEach(courbe.points) { p in
                        LineMark(x: .value("Prédite", p.predite), y: .value("Observée", p.observee),
                                 series: .value("Série", courbe.libelle))
                            .foregroundStyle(couleurs[i % couleurs.count])
                        PointMark(x: .value("Prédite", p.predite), y: .value("Observée", p.observee))
                            .foregroundStyle(couleurs[i % couleurs.count])
                            .symbolSize(30)
                    }
                }
            }
            .chartXScale(domain: 0...1)
            .chartYScale(domain: 0...1)
            .chartXAxisLabel("Probabilité prédite")
            .chartYAxisLabel("Fréquence observée")
            .chartXAxis {
                AxisMarks(values: [0, 0.2, 0.4, 0.6, 0.8, 1]) { _ in
                    AxisGridLine().foregroundStyle(Theme.piste)
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks(values: [0, 0.2, 0.4, 0.6, 0.8, 1]) { _ in
                    AxisGridLine().foregroundStyle(Theme.piste)
                    AxisValueLabel()
                }
            }
            .frame(height: 320)

            HStack(spacing: Theme.espaceM) {
                ForEach(Array(b.calibration.enumerated()), id: \.offset) { i, courbe in
                    HStack(spacing: 6) {
                        Circle().fill(couleurs[i % couleurs.count]).frame(width: 8, height: 8)
                        Text(courbe.libelle)
                    }
                }
                HStack(spacing: 6) {
                    Rectangle().fill(Color.secondary).frame(width: 14, height: 1)
                    Text("Calibration parfaite")
                }
            }
            .font(Theme.legende)
            .foregroundColor(.secondary)
        }
        .padding(Theme.espaceM)
        .frame(maxWidth: 640, alignment: .leading)
        .carte()
    }

    // MARK: - Calibration sur l'historique

    @ViewBuilder
    private var sectionCalibration: some View {
        let saisons = Array(Set(vm.historiqueAnterieur.map(\.saison))).sorted()
        VStack(alignment: .leading, spacing: Theme.espaceL) {
            Text("Calibration sur l'historique")
                .font(Theme.section)
            if saisons.count < 2 {
                EtatVide(icone: "clock.arrow.circlepath", titre: "Pas assez d'historique",
                         detail: "Téléchargez les 10 saisons précédentes de Ligue 1 sur football-data.co.uk (fichiers F1.csv), "
                         + "puis importez-les : la calibration se fait à l'import. Deux saisons terminées au minimum ; "
                         + "d'ici là, le modèle tourne avec ses valeurs de départ.")
            } else {
                HStack(spacing: Theme.espaceM) {
                    Button {
                        vm.lancerCalibration()
                    } label: {
                        Label(vm.calibrationEnCours ? "Calibration en cours…"
                              : vm.calibration == nil ? "Afficher le détail de la calibration" : "Recalibrer",
                              systemImage: vm.calibrationEnCours ? "hourglass" : "slider.horizontal.3")
                    }
                    .boutonVerreProeminent()
                    .disabled(vm.calibrationEnCours || vm.importEnCours)
                    if vm.calibrationEnCours {
                        ProgressView(value: vm.progressionCalibration)
                            .frame(width: 180)
                    } else if vm.calibrationCalculee, vm.calibration == nil {
                        Label("Rien à évaluer : aucune cote dans l'historique.", systemImage: "exclamationmark.triangle.fill")
                            .font(Theme.legende)
                            .foregroundColor(Theme.perte)
                    }
                    Spacer()
                }

                Text("\(saisons.count) saisons importées (\(saisons.first ?? "") à \(saisons.last ?? "")). Chacune, sauf la "
                     + "première qui sert de point de départ, est rejouée bloc de matchs par bloc de matchs : le modèle ne voit "
                     + "que les matchs déjà joués, puis prédit les suivants, comparé aux cotes de clôture (Pinnacle de "
                     + "préférence, marge retirée). Les paramètres sont choisis un à un à la meilleure log-loss : β (part des "
                     + "cotes dans les données), ξ (oubli des matchs anciens), ridge (prudence sur les forces), pénalité des "
                     + "promus. Le résultat est mis en service aussitôt, à chaque import qui change l'historique. Seules "
                     + "les saisons antérieures à la saison en cours servent : le backtest ci-dessus vérifie le gain sur "
                     + "une saison que la calibration n'a pas vue.")
                    .font(Theme.legende)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let c = vm.calibration {
                    resultatCalibration(c)
                }
            }
        }
    }

    private func resultatCalibration(_ c: ResultatCalibration) -> some View {
        let actuels = vm.reglages.parametresModele
        return VStack(alignment: .leading, spacing: Theme.espaceM) {
            HStack(spacing: Theme.espaceM) {
                TuileChiffre(titre: "Valeurs de départ", valeur: Format.nombre(c.depart.logLoss, decimales: 4, fixe: true),
                             detail: "log-loss, avant calibration", icone: "flag")
                TuileChiffre(titre: "Paramètres calibrés", valeur: Format.nombre(c.calibre.logLoss, decimales: 4, fixe: true),
                             detail: "log-loss · \(Format.signe(c.calibre.logLoss - c.depart.logLoss, decimales: 4))",
                             icone: "slider.horizontal.3",
                             couleurValeur: c.calibre.logLoss < c.depart.logLoss ? Theme.gain : .primary)
                TuileChiffre(titre: "Marché (clôture)", valeur: Format.nombre(c.marche.logLoss, decimales: 4, fixe: true),
                             detail: "log-loss, mêmes \(c.n) matchs", icone: "building.columns")
                TuileChiffre(titre: "Poids modèle optimal", valeur: Format.nombre(c.poidsModeleOptimal, decimales: 1, fixe: true),
                             detail: "0 = rien de plus que les cotes", icone: "scalemass")
            }
            .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: Theme.espaceS) {
                Text("Retenus : \(c.parametres.resume)")
                    .font(Theme.corps)
                    .textSelection(.enabled)
                Text(actuels == c.parametres ? "En service."
                     : "En service : \(actuels.map(\.resume) ?? "valeurs de départ (non calibré)")")
                    .font(Theme.legende)
                    .foregroundColor(.secondary)
            }
            .padding(Theme.espaceM)
            .frame(maxWidth: .infinity, alignment: .leading)
            .carte()

            HStack(alignment: .top, spacing: Theme.espaceM) {
                essais(c)
                parSaison(c)
            }
        }
    }

    private func essais(_ c: ResultatCalibration) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.espaceS) {
                Text("Paramètre").frame(width: 120, alignment: .leading)
                Text("Valeur essayée").frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)
                Text("Log-loss").frame(width: 80, alignment: .trailing)
            }
            .font(Theme.legende.weight(.semibold))
            .foregroundColor(.secondary)
            .padding(.vertical, 6)
            .padding(.horizontal, Theme.espaceS)
            Divider()
            ForEach(c.essais) { e in
                HStack(spacing: Theme.espaceS) {
                    Text(e.parametre).frame(width: 120, alignment: .leading)
                    Text(e.valeur + (e.retenu ? "  ← retenu" : "")).frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)
                    Text(Format.nombre(e.logLoss, decimales: 4, fixe: true))
                        .fontWeight(e.retenu ? .semibold : .regular)
                        .foregroundColor(e.retenu ? Theme.gain : .primary)
                        .frame(width: 80, alignment: .trailing)
                }
                .font(Theme.corps)
                .monospacedDigit()
                .padding(.vertical, 3)
                .padding(.horizontal, Theme.espaceS)
                .background(e.retenu ? Theme.accent.opacity(0.08) : .clear,
                            in: RoundedRectangle(cornerRadius: Theme.rayonPetit / 2))
            }
        }
        .padding(Theme.espaceS)
        .carte()
    }

    private func parSaison(_ c: ResultatCalibration) -> some View {
        func f(_ v: Double) -> String { Format.nombre(v, decimales: 4, fixe: true) }
        return VStack(spacing: 0) {
            HStack(spacing: Theme.espaceS) {
                Text("Saison").frame(width: 70, alignment: .leading)
                Text("Matchs").frame(width: 54, alignment: .trailing)
                Text("Départ").frame(width: 80, alignment: .trailing)
                Text("Calibré").frame(width: 80, alignment: .trailing)
                Text("Marché").frame(width: 80, alignment: .trailing)
            }
            .font(Theme.legende.weight(.semibold))
            .foregroundColor(.secondary)
            .padding(.vertical, 6)
            .padding(.horizontal, Theme.espaceS)
            Divider()
            ForEach(c.saisons) { s in
                HStack(spacing: Theme.espaceS) {
                    Text(s.saison).frame(width: 70, alignment: .leading)
                    Text("\(s.n)").frame(width: 54, alignment: .trailing)
                    Text(f(s.logLossDepart)).frame(width: 80, alignment: .trailing)
                    Text(f(s.logLossCalibre))
                        .foregroundColor(s.logLossCalibre < s.logLossDepart ? Theme.gain : .primary)
                        .frame(width: 80, alignment: .trailing)
                    Text(f(s.logLossMarche)).frame(width: 80, alignment: .trailing)
                }
                .font(Theme.corps)
                .monospacedDigit()
                .padding(.vertical, 3)
                .padding(.horizontal, Theme.espaceS)
            }
        }
        .padding(Theme.espaceS)
        .fixedSize()
        .carte()
    }
}
