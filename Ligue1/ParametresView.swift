//
//  ParametresView.swift
//  Predict
//  © 2026 Stephen O'Donnell, Tanguy Labbe · GNU GPL v3 ou ultérieure (fichier LICENSE).
//
//  Fenêtre Paramètres (⌘,) : saison, sauvegarde, export, apparence.
//
import SwiftUI
import Security

/// Racine de la fenêtre Paramètres.
///
/// Le TabView doit être la vue racine de la scène `Settings` : enveloppé dans un
/// `Group` conditionnel, macOS retombait sur un style d'onglets ordinaire,
/// sans la barre d'icônes des préférences.
struct ParametresView: View {
    @EnvironmentObject var vm: Ligue1ViewModel

    var body: some View {
        TabView {
            OngletSaison()
                .tabItem { Label("Saison", systemImage: "soccerball") }
            OngletSauvegarde()
                .tabItem { Label("Sauvegarde", systemImage: "externaldrive.fill") }
            OngletExport()
                .tabItem { Label("Export", systemImage: "square.and.arrow.up") }
            OngletApparence()
                .tabItem { Label("Apparence", systemImage: "paintbrush.fill") }
            OngletAide()
                .tabItem { Label("Aide", systemImage: "questionmark.circle") }
            OngletAPropos()
                .tabItem { Label("À propos", systemImage: "info.circle") }
        }
        .frame(width: 620, height: 500)
    }
}

/// Message de résultat d'une action, pour ne pas avaler les échecs silencieusement.
private struct Statut: View {
    let texte: String
    let ok: Bool

    var body: some View {
        Label(texte, systemImage: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .font(Theme.legende)
            .foregroundColor(ok ? .green : .orange)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Saison

/// Données (CSV football-data.co.uk) : saison en cours, historique, paramètres du modèle, logos.
private struct OngletSaison: View {
    @EnvironmentObject var vm: Ligue1ViewModel
    @State private var statut: (texte: String, ok: Bool)?
    @State private var effacerHistorique = false

    private var resumeHistorique: String {
        let h = vm.historique
        guard let premiere = h.saisons.first, let derniere = h.saisons.last else { return "aucun" }
        let ignorees = Set(h.matches.filter { ($0.jour ?? 0) >= vm.reglages.jourDebutSaison }.map(\.season)).sorted()
        return "\(h.saisons.count) saison\(h.saisons.count > 1 ? "s" : "") (\(premiere) à \(derniere)) · "
            + "\(h.matches.count) matchs, \(h.matches.filter { $0.odds != nil }.count) avec cotes"
            + (ignorees.isEmpty ? "" : " · \(ignorees.joined(separator: ", ")) ignorée (saison en cours ou suivante)")
    }

    /// Équipes absentes de la dernière saison de l'historique.
    private var promus: [String] {
        let anterieur = vm.historiqueAnterieur
        guard let derniere = anterieur.last?.saison else { return [] }
        let anciennes = Set(anterieur.filter { $0.saison == derniere }.flatMap { [$0.domicile, $0.exterieur] })
        return vm.ligue.equipes.filter { !anciennes.contains($0) }
    }

    private var resumeParametres: String {
        guard let p = vm.reglages.parametresModele else {
            return "non calibrés (2 saisons d'historique au moins) : valeurs de départ "
                + ParametresModele.depart.resume
        }
        let n = Set(vm.historiqueAnterieur.map(\.saison)).count
        return "calibrés sur \(n) saison\(n > 1 ? "s" : "") : \(p.resume)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Données")
                    .font(Theme.section)

                VStack(alignment: .leading, spacing: Theme.espaceXS) {
                    ligne("Saison en cours", !vm.saisonDisponible ? "aucune"
                          : "\(vm.ligue.season ?? "") · \(vm.ligue.teams.count) équipes · \(vm.ligue.nJournees) journées · "
                          + "\(vm.ligue.matchsJoues.count) / \(vm.ligue.matches.count) matchs joués · début "
                          + vm.reglages.debutSaison)
                    if vm.saisonDisponible {
                        ligne("Promus", promus.isEmpty ? "inconnus (pas d'historique de la saison précédente)"
                              : promus.joined(separator: ", "))
                    }
                    ligne("Historique", resumeHistorique)
                    ligne("Modèle", resumeParametres)
                }
                .padding(Theme.espaceS)
                .carte(Theme.rayonPetit)

                EtapesCSV()
                HStack(alignment: .top) {
                    BoutonImportCSV()
                    Spacer()
                    Button("Effacer l'historique…", role: .destructive) { effacerHistorique = true }
                        .disabled(vm.historique.matches.isEmpty || !vm.peutModifier(.historique)
                                  || vm.calibrationEnCours || vm.importEnCours)
                }
                Text("Journées : déduites des dates (un match reporté retrouve sa journée), les matchs pas encore "
                     + "programmés complètent le calendrier. Pour la pondération du modèle, la journée J est datée du "
                     + "début + 7 × (J − 1) jours (demi-vie ≈ \(vm.reglages.parametresEnService.demiVie) jours).")
                    .font(Theme.legende)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                Text("Cotes Winamax, Unibet et Betclic")
                    .font(Theme.section)
                ReglageCotesEnLigne()

                Divider()

                Text("Logos des clubs")
                    .font(Theme.section)
                HStack {
                    Button {
                        vm.importerLogos()
                    } label: {
                        Label("Importer des logos…", systemImage: "photo.on.rectangle")
                    }
                    Button {
                        if let d = vm.dossierLogosLocal {
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: d.path)
                        }
                    } label: {
                        Label("Afficher le dossier", systemImage: "folder")
                    }
                    Button("Recharger") { vm.rechargerLogos() }
                    Spacer()
                    Text("\(vm.logos.count) / \(vm.ligue.teams.count) logos personnalisés")
                        .font(Theme.legende)
                        .foregroundColor(.secondary)
                }
                Text("Les vrais écussons sont des marques déposées : l'application n'en télécharge aucun et dessine "
                     + "à défaut un blason aux couleurs du club. Pour utiliser vos propres images (usage personnel), "
                     + "déposez des PNG carrés nommés comme les clubs, espaces remplacés par « _ » (ex. "
                     + "Paris_Saint_Germain.png).")
                    .font(Theme.legende)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let statut {
                    Statut(texte: statut.texte, ok: statut.ok)
                }

                Spacer(minLength: 0)
            }
            .padding()
        }
        .confirmationDialog("Effacer l'historique ?", isPresented: $effacerHistorique) {
            Button("Effacer", role: .destructive) {
                if let e = vm.effacerHistorique() { statut = (e, false) }
                else { statut = ("Historique effacé : paramètres du modèle revenus aux valeurs de départ.", true) }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Les paramètres calibrés dessus sont effacés aussi. Les CSV d'origine ne sont pas touchés : vous "
                 + "pourrez les réimporter.")
        }
    }

    private func ligne(_ titre: String, _ valeur: String) -> some View {
        HStack(alignment: .top) {
            Text(titre)
                .foregroundColor(.secondary)
                .frame(width: 130, alignment: .leading)
            Text(valeur)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(Theme.corps)
    }
}

/// Clé The Odds API et téléchargement des cotes Winamax, Unibet et Betclic.
private struct ReglageCotesEnLigne: View {
    @EnvironmentObject var vm: Ligue1ViewModel
    @State private var cle = ""
    @State private var statut: (texte: String, ok: Bool)?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.espaceS) {
            HStack(spacing: Theme.espaceM) {
                SecureField("Clé The Odds API", text: $cle)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 280)
                    .onSubmit(enregistrer)
                Button("Enregistrer", action: enregistrer)
                    .disabled(cle.trimmingCharacters(in: .whitespacesAndNewlines) == vm.cleCotesEnLigne)
                Button {
                    actualiser()
                } label: {
                    Label(vm.cotesEnCours ? "Téléchargement…" : "Actualiser les cotes", systemImage: "arrow.down.circle")
                }
                .disabled(!vm.cotesEnLigneConfigurees || vm.cotesEnCours || vm.importEnCours
                          || vm.blocageIntegrite != nil)
                if vm.cotesEnCours {
                    ProgressView().controlSize(.small)
                }
            }
            .font(Theme.corps)
            HStack(spacing: Theme.espaceM) {
                Button {
                    statut = nil
                    vm.telechargerXg { statut = ($0, $1) }
                } label: {
                    Label(vm.xgEnCours ? "Téléchargement…" : "Actualiser les xG", systemImage: "chart.bar")
                }
                .disabled(vm.xgEnCours || vm.importEnCours || vm.blocageIntegrite != nil || !vm.saisonDisponible)
                if vm.xgEnCours {
                    ProgressView().controlSize(.small)
                }
                Text("xG des matchs joués, depuis Understat (aucune clé). Un xG déjà saisi n'est jamais écrasé ; un match absent reçoit aussi son score.")
                    .font(Theme.legende)
                    .foregroundColor(.secondary)
            }
            .font(Theme.corps)
            Link(destination: CotesEnLigne.site) {
                Label("Obtenir une clé gratuite (the-odds-api.com)", systemImage: "safari")
            }
            .font(Theme.corps)
            Text("Cotes 1/N/2 des matchs à venir, téléchargées aussi à chaque « Mettre à jour en ligne ». La cote "
                 + "téléchargée remplace celle du bookmaker tant que le match n'est pas joué ; un match joué garde les "
                 + "siennes. Bwin vient du CSV de football-data.co.uk. Offre gratuite : 500 crédits par mois, 1 par "
                 + "téléchargement. La clé reste sur ce Mac et n'est envoyée qu'à the-odds-api.com.")
                .font(Theme.legende)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let statut {
                Statut(texte: statut.texte, ok: statut.ok)
            }
        }
        .onAppear { cle = vm.cleCotesEnLigne }
    }

    private func enregistrer() {
        if let e = vm.definirCleCotes(cle) {
            statut = (e, false)
            return
        }
        cle = vm.cleCotesEnLigne
        statut = (vm.cotesEnLigneConfigurees ? "Clé enregistrée." : "Clé effacée.", true)
    }

    private func actualiser() {
        statut = nil
        vm.telechargerCotes { statut = ($0, $1) }
    }
}

// MARK: - Bloc « dernière sauvegarde »

private struct LigneSauvegarde: View {
    let titre: String
    let icone: String
    let sauvegarde: Sauvegarde?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(titre, systemImage: icone)
                .font(Theme.section)

            if let s = sauvegarde {
                Text(s.dateLisible)
                    .font(Theme.corps)

                HStack(spacing: 6) {
                    Text(s.cheminLisible)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.middle)

                    Spacer()

                    if s.existeEncore {
                        Button {
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: s.chemin)
                        } label: {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.borderless)
                        .help("Afficher dans le Finder")
                    } else {
                        Label("dossier introuvable", systemImage: "exclamationmark.triangle.fill")
                            .font(Theme.legende)
                            .foregroundColor(.orange)
                    }
                }
            } else {
                Text("Aucune sauvegarde enregistrée")
                    .font(Theme.corps)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .carte(Theme.rayonPetit)
    }
}

// MARK: - Sauvegarde

private struct OngletSauvegarde: View {
    @EnvironmentObject var vm: Ligue1ViewModel
    @State private var statut: (texte: String, ok: Bool)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LigneSauvegarde(
                titre: "Sauvegarde locale",
                icone: "internaldrive.fill",
                sauvegarde: vm.derniereSauvegardeLocale
            )

            Button {
                statut = vm.sauvegarderLocalement()
                    ? ("Sauvegarde locale effectuée.", true)
                    : ("Échec de la sauvegarde locale — voir le message d'erreur.", false)
            } label: {
                Label("Sauvegarder localement", systemImage: "arrow.down.doc")
            }

            if let statut {
                Statut(texte: statut.texte, ok: statut.ok)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Export

private struct OngletExport: View {
    @EnvironmentObject var vm: Ligue1ViewModel
    @State private var statut: (texte: String, ok: Bool)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Exporter les données")
                .font(Theme.section)

            Text("Les exports ne sont pas chiffrés : vous choisissez où les enregistrer.")
                .font(Theme.legende)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                // nil = annulation ou échec ; sans ce retour l'échec serait invisible.
                if let url = vm.exporterCSV() {
                    statut = ("Exporté : \(url.lastPathComponent)", true)
                }
            } label: {
                Label("Tout exporter en CSV (Excel)", systemImage: "tablecells")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .disabled(vm.ligue.teams.isEmpty)
            Text("Matchs (scores, xG, cotes des 4 bookmakers, probabilités figées, minutes de but), classement "
                 + "général et paris réglés avec les réglages actuels (mises et gains des 4 méthodes).")
                .font(Theme.legende)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Text("Fichiers de données")
                .font(Theme.section)
            Text("Le dossier de données contient league_data.json (saison en cours), history.json (saisons passées), "
                 + "app_state.json (réglages et paramètres du modèle), bankroll_events.json, manual_bets.json et "
                 + "excluded_bets.json, chacun accompagné d'un sceau .hmac.")
                .font(Theme.legende)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                if let d = vm.dossierLocal {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: d.path)
                }
            } label: {
                Label("Afficher les données dans le Finder", systemImage: "folder")
            }

            if let statut {
                Statut(texte: statut.texte, ok: statut.ok)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Apparence

private struct OngletApparence: View {
    @AppStorage(MenuItem.cleMasquees) private var sectionsMasquees = ""

    private func visible(_ item: MenuItem) -> Binding<Bool> {
        Binding(
            get: { !MenuItem.masquees(sectionsMasquees).contains(item.id) },
            set: { montrer in
                var cachees = MenuItem.masquees(sectionsMasquees)
                if montrer { cachees.remove(item.id) } else { cachees.insert(item.id) }
                sectionsMasquees = MenuItem.toutes.map(\.id).filter { cachees.contains($0) }.joined(separator: ",")
            }
        )
    }

    var body: some View {
        // Avec la liste des sections, le contenu peut dépasser la hauteur fixe de la fenêtre.
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Thème")
                    .font(Theme.section)

                ApparencePicker()

                Text("« Système » suit le réglage d'apparence de macOS.")
                    .font(Theme.legende)
                    .foregroundColor(.secondary)

                Divider()

                Text("Sections de la barre latérale")
                    .font(Theme.section)

                ForEach(MenuItem.toutes) { item in
                    Toggle(isOn: visible(item)) {
                        Label(item.title, systemImage: item.icon)
                    }
                    .disabled(item.id == MenuItem.obligatoire)
                }
                .font(Theme.corps)

                Text("Les sections décochées disparaissent de la barre latérale ; leurs données sont conservées. "
                     + "Le tableau de bord reste toujours affiché.")
                    .font(Theme.legende)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Aide

/// Mode d'emploi, rubrique par rubrique, dans l'ordre où l'on découvre l'app.
private struct OngletAide: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.espaceS) {
                Text("Comment utiliser Predict")
                    .font(Theme.section)
                Text("Dépliez une rubrique. L'application estime la force de chaque équipe (modèle Dixon-Coles), "
                     + "simule la fin de saison et teste une stratégie de paris sur les cotes saisies.")
                    .font(Theme.legende)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Rubrique("Premiers pas", icone: "1.circle", lignes: [
                    "Onglet Saison : importez les CSV de football-data.co.uk (saison en cours et 10 saisons passées) ; c'est la seule source de données.",
                    "Les données sont enregistrées dans Documents › Predict.",
                    "Pas de mot de passe : l'application s'ouvre directement sur le tableau de bord.",
                    "Tout ce que vous modifiez est enregistré aussitôt (cotes, xG, minutes et jauges après 0,4 s sans frappe)."
                ])
                Rubrique("Tableau de bord", icone: "chart.bar.xaxis", lignes: [
                    "Première section : prochaine journée avec les probabilités du modèle, paris conseillés et leur verdict, haut et bas du classement avec les chances de titre, de top 3 et des 3 dernières places, bankroll simulée ¼ Kelly.",
                    "« À surveiller » signale ce qui demande une action : mise à jour en retard, cotes de bookmaker manquantes, modèle non calibré, règle de paris perdante.",
                    "Chaque semaine, « Mettre à jour en ligne » depuis le tableau de bord suffit ; les liens de chaque carte ouvrent la section détaillée.",
                    "Paramètres › Apparence : décochez les sections que vous n'utilisez pas ; le tableau de bord reste toujours affiché."
                ])
                Rubrique("Journées & cotes", icone: "sportscourt", lignes: [
                    "Une carte par match : date, score, xG, minutes des buts, forfait, cotes de référence du CSV et cotes Winamax, Unibet, Bwin et Betclic à saisir.",
                    "Scores et cotes de référence arrivent avec le CSV de la saison ; un score importé fige la probabilité pré-match du modèle ajusté sur les journées précédentes.",
                    "Avant le match : probabilités 1/N/2 du modèle en direct, ou des xG saisis s'ils sont renseignés.",
                    "Au premier score validé, la probabilité pré-match est figée et ne sera plus jamais recalculée, même si vous corrigez le score. « Effacer » la libère.",
                    "Le xG réel nourrit aussi le modèle (mélange 50 % buts, 50 % xG) et donne la ligne « Après-match ».",
                    "Minutes des buts (« 23, 45+4, 78 ») : seulement pour la règle Winamax des 2 buts d'avance ; leur nombre doit correspondre au score.",
                    "Forfait : le score compte au classement mais le match n'alimente plus le modèle.",
                    "Écarts « vs bookmaker » et « vs réf. » : probabilité du modèle moins probabilité implicite (marge retirée) ; vert = modèle plus optimiste. La meilleure cote des quatre bookmakers sert aux paris, jamais la cote de référence."
                ])
                Rubrique("Classements et analyse", icone: "list.number", lignes: [
                    "Critères : général, domicile, extérieur, contre le top 9, contre le bottom 9, aux xPoints (points attendus d'après les xG).",
                    "Analyse équipe : forme sur 5 matchs, rang journée par journée, bilans par contexte avec moyennes, calendrier complet."
                ])
                Rubrique("Simulation des paris", icone: "eurosign.circle", lignes: [
                    "Seuls les matchs joués avec cotes et probabilité figée entrent dans la simulation ; les matchs à jouer avec cotes apparaissent « en attente » (probabilité en direct, sans impact).",
                    "Marché simple retenu s'il dépasse le seuil d'espérance et reste dans la fourchette de cotes (cote médiane entre bookmakers) ; double chance en plus d'un pari simple seulement.",
                    "Quatre méthodes de mise comparées : mise fixe, Kelly plein, demi-Kelly, quart-Kelly (Kelly plafonné à 25 %).",
                    "Cotes : meilleure des bookmakers saisis ; sans saisie, cote moyenne en ligne du CSV (« Moy. en ligne »), indicative.",
                    "Dépôts/retraits simulés, paris forcés (« [manuel] », mise fixe) et paris exclus ; tout est rejoué depuis le début à chaque changement."
                ])
                Rubrique("Probabilités finales et backtest", icone: "square.grid.3x3.fill", lignes: [
                    "Monte Carlo relancé en arrière-plan à chaque score validé ; nombre de saisons simulées réglable (2 000 à 50 000), ⌘R pour recalculer.",
                    "Backtest : pour chaque journée, le modèle ne voit que le passé, puis il est comparé au marché (log-loss, RPS, Brier).",
                    "Calibration : à chaque import qui change l'historique, chaque saison passée est rejouée pour choisir β, ξ, ridge et la pénalité des promus, aussitôt mis en service ; le détail est dans l'onglet Backtest."
                ])
                Rubrique("Conseils de paris", icone: "lightbulb", lignes: [
                    "Pour chaque match à venir retenu par les jauges : marché, cote, probabilité du modèle et du marché, espérance, mise ¼ Kelly et mise fixe.",
                    "Fiabilité : quand le modèle a annoncé une probabilité de la même tranche, fréquence réelle de l'issue sur les saisons passées (IC 95 %).",
                    "Historique : résultat des paris de même espérance que la règle actuelle aurait choisis sur les saisons passées, à la cote moyenne en ligne (ROI et IC 95 %).",
                    "Verdict : « Parier » si ce résultat est significativement positif, « Ne pas parier » s'il est négatif (ou si la règle entière perd), sinon « Petite mise au plus »."
                ])
                Rubrique("Données (football-data.co.uk)", icone: "tablecells", lignes: [
                    "Téléchargez vous-même les CSV du championnat affiché sur football-data.co.uk (un fichier par saison : F1, D1, E0, I1 ou SP1), et si vous le voulez fixtures.csv.",
                    "« Mettre à jour en ligne » : seul accès réseau de l'application (automatique au premier lancement). Il télécharge fixtures.csv, le CSV de la saison en cours et ceux des 10 saisons précédentes qui manquent, puis les importe ; rien n'est envoyé.",
                    "Avec une clé The Odds API (onglet Saison), il télécharge aussi les cotes Winamax, Unibet et Betclic des matchs à venir ; seule la clé est envoyée, à the-odds-api.com.",
                    "Importez-les tous d'un coup : la saison est déduite des dates. La plus récente devient la saison en cours, les autres forment l'historique ; une saison réimportée remplace l'ancienne.",
                    "Journées déduites des dates ; les matchs pas encore programmés complètent le calendrier jusqu'à la dernière journée.",
                    "Les saisons passées nourrissent le modèle (pondérées par leur ancienneté) ; la dernière d'entre elles désigne les promus.",
                    "Noms de clubs convertis pour l'affichage (« Paris SG » → « Paris Saint Germain »)."
                ])
                Rubrique("Sauvegarde et intégrité", icone: "lock.shield", lignes: [
                    "Les fichiers de données sont scellés par l'application : s'ils sont modifiés en dehors de Predict, une revue d'intégrité montre les différences avant d'accepter ou refuser, et la saisie est bloquée en attendant.",
                    "Chaque enregistrement est écrit dans Documents › Predict ; la dernière sauvegarde est affichée dans la barre latérale."
                ])
                Rubrique("Raccourcis", icone: "keyboard", lignes: [
                    "⌘R : recalculer le classement final.  ⌘, : Paramètres.",
                    "Entrée dans un champ de score : valider le score.",
                    "Apparence : menu Présentation ou onglet Apparence (clair, sombre, système, sections de la barre latérale)."
                ])
                Rubrique("Limites à connaître", icone: "exclamationmark.triangle", lignes: [
                    "Égalité parfaite : points, différence de buts, buts marqués — sans le mini-championnat des confrontations directes.",
                    "Les CSV apportent les cotes de référence (Pinnacle, moyenne du marché) et Bwin ; Winamax, Unibet et Betclic viennent de The Odds API (clé requise) ou de la saisie.",
                    "Pas de xG dans les CSV : à saisir si vous le voulez.",
                    "Les journées des matchs non programmés sont provisoires ; fixtures.csv donne les vraies au fil des semaines.",
                    "Simulation à but d'étude : aucun résultat passé ne garantit un gain futur."
                ])
            }
            .padding()
        }
    }
}

/// Rubrique dépliable de l'aide.
private struct Rubrique: View {
    let titre: String
    let icone: String
    let lignes: [String]

    init(_ titre: String, icone: String, lignes: [String]) {
        self.titre = titre
        self.icone = icone
        self.lignes = lignes
    }

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(lignes, id: \.self) { ligne in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                        Text(ligne)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(Theme.corps)
                }
            }
            .padding(.top, 4)
            .padding(.leading, 2)
        } label: {
            Label(titre, systemImage: icone)
                .font(Theme.corps.weight(.semibold))
        }
        .padding(Theme.espaceS)
        .carte(Theme.rayonPetit)
    }
}

// MARK: - À propos

/// Version, configuration requise et environnement d'exécution : ce qu'il
/// faut pour un signalement ou pour savoir où sont les données.
private struct OngletAPropos: View {
    @EnvironmentObject var vm: Ligue1ViewModel
    @State private var copie = false

    private var infos: [String: Any] { Bundle.main.infoDictionary ?? [:] }
    private var version: String { infos["CFBundleShortVersionString"] as? String ?? "—" }
    private var build: String { infos["CFBundleVersion"] as? String ?? "—" }
    private var macOSMinimum: String { infos["LSMinimumSystemVersion"] as? String ?? "14.0" }
    private var identifiant: String { Bundle.main.bundleIdentifier ?? "—" }
    private var macOSInstalle: String { ProcessInfo.processInfo.operatingSystemVersionString }
    private var droits: String { infos["NSHumanReadableCopyright"] as? String ?? "© 2026 Stephen O'Donnell, Tanguy Labbe · GNU GPL v3 ou ultérieure" }

    private var architecture: String {
        #if arch(arm64)
        let slice = "Apple Silicon (arm64)"
        #else
        let slice = "Intel (x86_64)"
        #endif
        var translated: Int32 = 0
        var taille = MemoryLayout<Int32>.size
        if sysctlbyname("sysctl.proc_translated", &translated, &taille, nil, 0) == 0, translated == 1 {
            return slice + ", via Rosetta"
        }
        return slice
    }

    private var interface: String {
        if #available(macOS 26, *) { return "Verre liquide (macOS 26)" }
        return "Style classique (macOS 14 à 15)"
    }

    private var dateCompilation: String {
        guard let url = Bundle.main.executableURL,
              let date = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
        else { return "—" }
        return date.formatted(date: .long, time: .shortened)
    }

    /// Identité de signature ; sans certificat, la signature est ad hoc.
    private var signature: String {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(Bundle.main.bundleURL as CFURL, [], &code) == errSecSuccess, let code else { return "—" }
        var infos: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &infos) == errSecSuccess,
              let dict = infos as? [String: Any] else { return "—" }
        guard let certificats = dict[kSecCodeInfoCertificates as String] as? [SecCertificate], let premier = certificats.first else {
            return "ad hoc"
        }
        var nom: CFString?
        SecCertificateCopyCommonName(premier, &nom)
        return (nom as String?) ?? "certificat"
    }

    private var dossierCle: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Predict", isDirectory: true)
    }

    private var lignes: [(String, String)] {
        [
            ("Version", "\(version) (build \(build))"),
            ("Licence", droits),
            ("Compilée le", dateCompilation),
            ("Identifiant", identifiant),
            ("macOS minimum", macOSMinimum),
            ("macOS installé", macOSInstalle),
            ("Architecture", architecture),
            ("Interface", interface),
            ("Signature", signature),
            ("Stockage", "local"),
            ("Données locales", vm.dossierLocal?.path ?? "—"),
            ("Clé d'intégrité", dossierCle?.path ?? "—"),
            ("Modèle", "Dixon-Coles pondéré (\(vm.reglages.parametresModele == nil ? "non calibré, " : "")"
                + "\(vm.reglages.parametresEnService.resume), buts/xG \(Format.nombre(Modele.blendAlpha)))")
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: Theme.espaceM) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Predict")
                            .font(Theme.titre)
                        Text("Simulateur de fin de saison et de paris")
                            .font(Theme.legende)
                            .foregroundColor(.secondary)
                        Text(droits)
                            .font(Theme.legende)
                            .foregroundColor(.secondary)
                    }
                }

                VStack(spacing: Theme.espaceXS) {
                    ForEach(lignes, id: \.0) { ligne in
                        HStack(alignment: .top) {
                            Text(ligne.0)
                                .foregroundColor(.secondary)
                                .frame(width: 130, alignment: .leading)
                            Text(ligne.1)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .font(Theme.corps)
                    }
                }
                .padding(Theme.espaceS)
                .carte()

                HStack {
                    Button {
                        if let d = vm.dossierLocal {
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: d.path)
                        }
                    } label: {
                        Label("Afficher les données dans le Finder", systemImage: "folder")
                    }
                    Button {
                        let texte = lignes.map { "\($0.0) : \($0.1)" }.joined(separator: "\n")
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(texte, forType: .string)
                        copie = true
                    } label: {
                        Label(copie ? "Copié" : "Copier ces informations", systemImage: "doc.on.doc")
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Label("Logiciel libre — GNU GPL", systemImage: "chevron.left.forwardslash.chevron.right")
                        .font(Theme.corps)
                        .fontWeight(.semibold)
                    Text("Predict est un logiciel libre de Stephen O'Donnell et Tanguy Labbe, diffusé sous la licence publique "
                         + "générale GNU, version 3 ou ultérieure : vous pouvez l'utiliser, l'étudier, le modifier et le "
                         + "redistribuer, à condition que toute version redistribuée reste sous la même licence, code source "
                         + "compris. Fourni sans aucune garantie ; probabilités et conseils sont indicatifs. Texte complet dans "
                         + "le fichier LICENSE du code source. Les noms des championnats et les écussons des clubs sont des marques de leurs "
                         + "titulaires respectifs.")
                        .font(Theme.legende)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Theme.espaceS)
                .frame(maxWidth: .infinity, alignment: .leading)
                .carte()

                Text("Compilée sans Xcode avec les outils en ligne de commande (./build.sh), binaire universel. "
                     + "Données scellées localement ; aucune donnée n'est envoyée sur le réseau par l'application, qui "
                     + "ne s'y connecte que sur « Mettre à jour en ligne » (téléchargement depuis football-data.co.uk) "
                     + "et pour les cotes en ligne (the-odds-api.com, qui ne reçoit que la clé).")
                    .font(Theme.legende)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .padding()
        }
    }
}
