//
//  Moteur.swift
//  Predict
//  © 2026 Stephen O'Donnell, Tanguy Labbe · GNU GPL v3 ou ultérieure (fichier LICENSE).
//
//  Moteur (model.py de l'app Python) : modèle Dixon-Coles par estimation
//  conjointe pondérée dans le temps, classements, analyse d'une équipe,
//  Monte Carlo de fin de saison, cotes, backtest walk-forward, calibration
//  des hyperparamètres sur l'historique.
//
//  log(λ dom.) = base + avantage terrain + attaque dom. + défense ext.
//  log(λ ext.) = base + attaque ext. + défense dom.
//  Forces régularisées (ridge) vers 0, matchs pondérés par exp(-ξ × jours),
//  pénalité « promu » pour toute équipe absente de la saison précédente.
//  Données : CSV de football-data.co.uk (saison en cours et historique) et
//  saisies de l'utilisateur ; ξ, ridge, β et pénalité promu sont calibrés sur
//  l'historique.
//
import Foundation

enum Modele {
    static let maxButs = 10
    /// Cadence approximative entre deux journées.
    static let ecartJournees = 7

    /// Poids des pseudo-matchs de la pénalité « promu » : quelques matchs, qui
    /// s'effacent ensuite devant les vrais.
    static let poidsPseudoPromu = 3.0

    /// Part des buts réels dans l'observation (le reste en xG quand il est saisi).
    static let blendAlpha = 0.5
    /// ρ utilisé pour les probabilités calculées directement à partir de deux xG.
    static let rhoXg = -0.08

    /// Adversaire fictif « moyen » des pseudo-matchs de la pénalité promu.
    static let adversaireMoyen = "__avg__"

    /// Poids sous lequel un match de l'historique est ignoré (effet négligeable, calcul bien plus court).
    static let poidsMin = 1e-3

    // MARK: - Poisson / Dixon-Coles

    static let tailleGrille = maxButs + 1

    /// Loi de Poisson tronquée à `maxButs`, renormalisée.
    static func poisson(_ lambda: Double) -> [Double] {
        var pmf = [Double](repeating: 0, count: tailleGrille)
        pmf[0] = exp(-lambda)
        for k in 1..<tailleGrille { pmf[k] = pmf[k - 1] * lambda / Double(k) }
        let somme = pmf.reduce(0, +)
        return pmf.map { $0 / somme }
    }

    /// Matrice des scores (ligne = buts domicile, colonne = buts extérieur), à plat,
    /// avec la correction Dixon-Coles sur 0-0, 1-0, 0-1 et 1-1.
    static func matriceScores(_ lh: Double, _ la: Double, rho: Double) -> [Double] {
        let ph = poisson(lh), pa = poisson(la)
        let t = tailleGrille
        var m = [Double](repeating: 0, count: t * t)
        for i in 0..<t { for j in 0..<t { m[i * t + j] = ph[i] * pa[j] } }
        m[0] *= 1 - lh * la * rho
        m[t] *= 1 + la * rho
        m[1] *= 1 + lh * rho
        m[t + 1] *= 1 - rho
        var somme = 0.0
        for k in 0..<m.count {
            m[k] = max(m[k], 0)
            somme += m[k]
        }
        return m.map { $0 / somme }
    }

    static func issues(_ m: [Double]) -> (p1: Double, pN: Double, p2: Double) {
        let t = tailleGrille
        var p1 = 0.0, pN = 0.0, p2 = 0.0
        for i in 0..<t {
            for j in 0..<t {
                if i > j { p1 += m[i * t + j] } else if i == j { pN += m[i * t + j] } else { p2 += m[i * t + j] }
            }
        }
        return (p1, pN, p2)
    }

    /// Probabilités 1/N/2 calculées directement à partir de deux xG.
    static func probabilitesXg(_ xgDomicile: Double, _ xgExterieur: Double) -> Probas {
        let h = min(max(xgDomicile, 0.05), 6), a = min(max(xgExterieur, 0.05), 6)
        let p = issues(matriceScores(h, a, rho: rhoXg))
        return Probas(p1: p.p1, pN: p.pN, p2: p.p2, lambdaDomicile: h, lambdaExterieur: a)
    }
}

/// Hyperparamètres du modèle, choisis par la calibration walk-forward sur
/// l'historique (onglet Backtest).
struct ParametresModele: Codable, Hashable {
    /// Décroissance temporelle : poids exp(-ξ × jours).
    var xi = 0.005
    /// Régularisation des forces d'équipe (shrinkage).
    var ridge = 0.08
    /// Part des buts attendus implicites des cotes dans l'observation d'un match joué avec cotes.
    var marketAlpha = 0.5
    /// Pénalité « promu » (log) sur l'attaque et la défense.
    var penaliteAttaquePromu = 0.0
    var penaliteDefensePromu = 0.0

    /// Point de départ de la calibration, et valeurs provisoires tant qu'elle n'a
    /// pas eu lieu : milieux des grilles essayées, aucune pénalité promu.
    static let depart = ParametresModele()

    enum CodingKeys: String, CodingKey {
        case xi, ridge
        case marketAlpha = "market_alpha"
        case penaliteAttaquePromu = "promoted_attack", penaliteDefensePromu = "promoted_defense"
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ParametresModele.depart
        xi = try c.decodeIfPresent(Double.self, forKey: .xi) ?? d.xi
        ridge = try c.decodeIfPresent(Double.self, forKey: .ridge) ?? d.ridge
        marketAlpha = try c.decodeIfPresent(Double.self, forKey: .marketAlpha) ?? d.marketAlpha
        penaliteAttaquePromu = try c.decodeIfPresent(Double.self, forKey: .penaliteAttaquePromu) ?? d.penaliteAttaquePromu
        penaliteDefensePromu = try c.decodeIfPresent(Double.self, forKey: .penaliteDefensePromu) ?? d.penaliteDefensePromu
    }

    var valide: Bool {
        [xi, ridge, marketAlpha, penaliteAttaquePromu, penaliteDefensePromu].allSatisfy(\.isFinite)
            && (0.0005...0.05).contains(xi) && (0.001...5).contains(ridge) && (0...1).contains(marketAlpha)
            && (-1...1).contains(penaliteAttaquePromu) && (-1...1).contains(penaliteDefensePromu)
    }

    /// Demi-vie de la pondération temporelle, en jours.
    var demiVie: Int { Int((log(2) / max(xi, 1e-6)).rounded()) }

    var resume: String {
        "ξ = \(Format.nombre(xi, decimales: 4)) (demi-vie \(demiVie) j), ridge \(Format.nombre(ridge, decimales: 3)), "
            + "cotes β = \(Format.nombre(marketAlpha)), promus \(Format.signe(penaliteAttaquePromu, decimales: 2)) / "
            + "\(Format.signe(penaliteDefensePromu, decimales: 2))"
    }
}

struct Probas: Equatable {
    var p1: Double
    var pN: Double
    var p2: Double
    var lambdaDomicile: Double
    var lambdaExterieur: Double

    var triplet: [Double] { [p1, pN, p2] }
}

// MARK: - Règle « 2 buts d'avance » (Winamax)

enum MinutesBut {
    struct Erreur: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private static func invalide(_ brut: String) -> Erreur {
        Erreur(message: "minute invalide : '\(brut)' (format attendu : '23' ou '45+4')")
    }

    /// « 23 » → 23 ; « 45+4 » → 45,04 (juste après 45, avant 46).
    static func valeur(_ brut: String) throws -> Double {
        let texte = brut.trimmingCharacters(in: .whitespaces)
        guard !texte.isEmpty else { throw Erreur(message: "minute vide") }
        let parties = texte.split(separator: "+", omittingEmptySubsequences: false).map(String.init)
        guard parties.count <= 2 else { throw invalide(texte) }
        func nombre(_ s: String) -> Double? {
            guard !s.isEmpty, !s.hasPrefix("+"), !s.hasPrefix("-") else { return nil }
            return Double(s.trimmingCharacters(in: .whitespaces))
        }
        let base: Double, ajout: Double
        if parties.count == 2 {
            guard let b = nombre(parties[0]), let a = nombre(parties[1]) else { throw invalide(texte) }
            base = b; ajout = a
        } else {
            guard let b = Double(texte) else { throw invalide(texte) }
            base = b; ajout = 0
        }
        guard base.isFinite, ajout.isFinite, base >= 0, ajout >= 0, ajout < 100 else { throw invalide(texte) }
        return base + ajout / 100
    }

    /// « 23, 45+4, 78 » → ["23", "45+4", "78"], ordre de saisie conservé.
    static func liste(_ texte: String) throws -> [String] {
        let parties = texte.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        for p in parties { _ = try valeur(p) }
        return parties
    }

    /// Reconstitue le fil du match : avance maximale de chaque équipe (≥ 0).
    static func avancesMax(_ domicile: [String], _ exterieur: [String]) throws -> (domicile: Int, exterieur: Int) {
        var evenements = try domicile.map { (try valeur($0), true) }
        evenements += try exterieur.map { (try valeur($0), false) }
        evenements.sort { $0.0 < $1.0 }
        var h = 0, a = 0, maxH = 0, maxA = 0
        for (_, estDomicile) in evenements {
            if estDomicile { h += 1 } else { a += 1 }
            maxH = max(maxH, h - a)
            maxA = max(maxA, a - h)
        }
        return (maxH, maxA)
    }

    /// Le nombre de minutes saisies doit correspondre au score final.
    static func valider(_ domicile: [String], _ exterieur: [String], butsDomicile h: Int, butsExterieur a: Int) throws {
        if domicile.count != h {
            throw Erreur(message: "\(domicile.count) minute(s) saisie(s) à domicile, mais le score est \(h)-\(a) "
                         + "(\(h) but(s) attendu(s) à domicile).")
        }
        if exterieur.count != a {
            throw Erreur(message: "\(exterieur.count) minute(s) saisie(s) à l'extérieur, mais le score est \(h)-\(a) "
                         + "(\(a) but(s) attendu(s) à l'extérieur).")
        }
    }
}

// MARK: - Dixon-Coles : estimation conjointe pondérée dans le temps

struct MatchPondere {
    let domicile: String
    let exterieur: String
    /// Observation : mélange buts/xG/cotes, pas forcément entière.
    let observationDomicile: Double
    let observationExterieur: Double
    /// Score réel entier (correction Dixon-Coles) ; nil pour les pseudo-matchs promu.
    let butsDomicile: Int?
    let butsExterieur: Int?
    let poids: Double
}

struct ModeleForces {
    let equipes: [String]
    let index: [String: Int]
    var attaque: [Double]
    var defense: [Double]
    static let baseLogDepart = log(1.35)

    var baseLog = ModeleForces.baseLogDepart
    var gammaLog = log(1.2)
    var rho = -0.08

    init(equipes: [String]) {
        self.equipes = equipes
        var idx: [String: Int] = [:]
        for (i, e) in equipes.enumerated() { idx[e] = i }
        index = idx
        attaque = [Double](repeating: 0, count: equipes.count)
        defense = [Double](repeating: 0, count: equipes.count)
    }

    func lambdas(_ domicile: String, _ exterieur: String) -> (Double, Double) {
        let h = index[domicile] ?? 0, a = index[exterieur] ?? 0
        return (exp(baseLog + gammaLog + attaque[h] + defense[a]), exp(baseLog + attaque[a] + defense[h]))
    }

    func probas(_ domicile: String, _ exterieur: String) -> Probas {
        let (lh, la) = lambdas(domicile, exterieur)
        let p = Modele.issues(Modele.matriceScores(lh, la, rho: rho))
        return Probas(p1: p.p1, pN: p.pN, p2: p.p2, lambdaDomicile: lh, lambdaExterieur: la)
    }

    /// Maximum de vraisemblance pondéré. La correction Dixon-Coles (τ, ρ) porte
    /// sur le score réel entier : appliquée au mélange, elle ne s'activerait jamais.
    mutating func ajuster(_ matchs: [MatchPondere], ridge: Double) {
        let n = equipes.count
        let k = matchs.count
        let hi = matchs.map { index[$0.domicile] ?? 0 }
        let ai = matchs.map { index[$0.exterieur] ?? 0 }
        let x = matchs.map(\.observationDomicile)
        let y = matchs.map(\.observationExterieur)
        let w = matchs.map(\.poids)
        // 0 : aucun, 1 : 0-0, 2 : 0-1, 3 : 1-0, 4 : 1-1
        let cas: [Int] = matchs.map { m in
            switch (m.butsDomicile, m.butsExterieur) {
            case (0?, 0?): return 1
            case (0?, 1?): return 2
            case (1?, 0?): return 3
            case (1?, 1?): return 4
            default: return 0
            }
        }

        func nll(_ theta: [Double]) -> (valeur: Double, gradient: [Double]) {
            let base = theta[2 * n], gamma = theta[2 * n + 1], rho = theta[2 * n + 2]
            var total = 0.0
            var grad = [Double](repeating: 0, count: 2 * n + 3)
            var sommeGh = 0.0, sommeGa = 0.0, gradRho = 0.0
            for m in 0..<k {
                let h = hi[m], a = ai[m]
                let logLh = base + gamma + theta[h] + theta[n + a]
                let logLa = base + theta[a] + theta[n + h]
                let lh = exp(logLh), la = exp(logLa)
                var tau = 1.0, dtauH = 0.0, dtauA = 0.0, dtauRho = 0.0
                switch cas[m] {
                case 1:
                    tau = 1 - lh * la * rho
                    dtauH = -lh * la * rho
                    dtauA = -lh * la * rho
                    dtauRho = -lh * la
                case 2:
                    tau = 1 + lh * rho
                    dtauH = lh * rho
                    dtauRho = lh
                case 3:
                    tau = 1 + la * rho
                    dtauA = la * rho
                    dtauRho = la
                case 4:
                    tau = 1 - rho
                    dtauRho = -1
                default:
                    break
                }
                if tau < 1e-6 {
                    tau = 1e-6
                    dtauH = 0; dtauA = 0; dtauRho = 0
                }
                let ll = x[m] * logLh - lh + y[m] * logLa - la + log(tau)
                total -= w[m] * ll
                let gh = -w[m] * (x[m] - lh + dtauH / tau)
                let ga = -w[m] * (y[m] - la + dtauA / tau)
                grad[h] += gh
                grad[a] += ga
                grad[n + a] += gh
                grad[n + h] += ga
                sommeGh += gh
                sommeGa += ga
                gradRho -= w[m] * dtauRho / tau
            }
            for i in 0..<n {
                total += ridge * (theta[i] * theta[i] + theta[n + i] * theta[n + i])
                grad[i] += 2 * ridge * theta[i]
                grad[n + i] += 2 * ridge * theta[n + i]
            }
            grad[2 * n] = sommeGh + sommeGa
            grad[2 * n + 1] = sommeGh
            grad[2 * n + 2] = gradRho
            return (total, grad)
        }

        let depart = attaque + defense + [baseLog, gammaLog, rho]
        let bornes = [(Double, Double)](repeating: (-2.5, 2.5), count: 2 * n)
            + [(log(0.3), log(3.0)), (log(0.8), log(2.0)), (-0.25, 0.25)]
        let r = Optimisation.minimiser(depart: depart, bornes: bornes, fonction: nll)
        attaque = Array(r.x[0..<n])
        defense = Array(r.x[n..<(2 * n)])
        baseLog = r.x[2 * n]
        gammaLog = r.x[2 * n + 1]
        rho = r.x[2 * n + 2]
    }
}

extension Modele {

    static func jourJournee(debutSaison: Int, _ journee: Int) -> Int {
        debutSaison + ecartJournees * (journee - 1)
    }

    /// Mélange buts réels et xG ; buts seuls si le xG n'est pas renseigné.
    static func observation(_ buts: (Int, Int), _ xg: (Double?, Double?), alpha: Double) -> (Double, Double) {
        guard let xh = xg.0, let xa = xg.1 else { return (Double(buts.0), Double(buts.1)) }
        return (alpha * Double(buts.0) + (1 - alpha) * xh, alpha * Double(buts.1) + (1 - alpha) * xa)
    }

    /// Ajuste le modèle sur l'historique (pondéré par ancienneté) et les matchs
    /// joués de la saison en cours avant `journeeReference` (tous si nil). Les
    /// promus sont les équipes absentes de la dernière saison de l'historique.
    static func construire(ligue: Ligue, historique: [MatchHistoriquePrepare] = [], debutSaison: Int,
                           journeeReference: Int? = nil, parametres: ParametresModele = .depart,
                           blendAlpha: Double = Modele.blendAlpha) -> ModeleForces {
        let xi = parametres.xi, marketAlpha = parametres.marketAlpha
        let courantes = ligue.equipes
        var anciennes = Set<String>()
        if let derniere = historique.last(where: { $0.jour < debutSaison })?.saison {
            anciennes = Set(historique.filter { $0.saison == derniere }.flatMap { [$0.domicile, $0.exterieur] })
        }

        let matchsCourants: [Match]
        let reference: Int
        if let j = journeeReference {
            matchsCourants = ligue.matchsJoues.filter { $0.journee < j && !$0.forfait }
            reference = jourJournee(debutSaison: debutSaison, j)
        } else {
            matchsCourants = ligue.matchsJoues.filter { !$0.forfait }
            reference = jourJournee(debutSaison: debutSaison, ligue.nJournees + 1)
        }

        var ponderes = Modele.ponderes(historique, avant: debutSaison, reference: reference, parametres: parametres)

        var lambdasMarche: [Match.ID: (Double, Double)] = [:]
        if marketAlpha > 0 {
            for m in matchsCourants {
                if let p = Cotes.probabilitesMarche(m) {
                    lambdasMarche[m.id] = Cotes.lambdasMarche(p)
                }
            }
        }
        for m in matchsCourants {
            guard let bh = m.butsDomicile, let ba = m.butsExterieur else { continue }
            let jour = jourJournee(debutSaison: debutSaison, m.journee)
            var (h, a) = observation((bh, ba), (m.xgDomicile, m.xgExterieur), alpha: blendAlpha)
            if let mkt = lambdasMarche[m.id] {
                h = marketAlpha * mkt.0 + (1 - marketAlpha) * h
                a = marketAlpha * mkt.1 + (1 - marketAlpha) * a
            }
            ponderes.append(MatchPondere(domicile: m.domicile, exterieur: m.exterieur,
                                         observationDomicile: h, observationExterieur: a,
                                         butsDomicile: bh, butsExterieur: ba,
                                         poids: exp(-xi * Double(max(reference - jour, 0)))))
        }

        // Pénalité promu : équipes de la saison en cours absentes de la précédente.
        let promus = courantes.filter { !anciennes.contains($0) }
        ponderes += pseudoMatchsPromus(promus, parametres: parametres)
        let univers = Set(courantes).union(anciennes).union(ponderes.flatMap { [$0.domicile, $0.exterieur] })
        var modele = ModeleForces(equipes: univers.sorted())
        modele.ajuster(ponderes, ridge: parametres.ridge)
        return modele
    }

    /// Matchs de l'historique joués avant le jour `avant`, pondérés à la date
    /// `reference` ; observation = cotes (β) mélangées aux buts, comme en saison.
    static func ponderes(_ historique: [MatchHistoriquePrepare], avant: Int, reference: Int,
                         parametres p: ParametresModele) -> [MatchPondere] {
        var resultat: [MatchPondere] = []
        for m in historique where m.jour < avant {
            let poids = exp(-p.xi * Double(max(reference - m.jour, 0)))
            guard poids >= poidsMin else { continue }
            var h = Double(m.butsDomicile), a = Double(m.butsExterieur)
            if p.marketAlpha > 0, let mkt = m.lambdasMarche {
                h = p.marketAlpha * mkt.0 + (1 - p.marketAlpha) * h
                a = p.marketAlpha * mkt.1 + (1 - p.marketAlpha) * a
            }
            resultat.append(MatchPondere(domicile: m.domicile, exterieur: m.exterieur,
                                         observationDomicile: h, observationExterieur: a,
                                         butsDomicile: m.butsDomicile, butsExterieur: m.butsExterieur, poids: poids))
        }
        return resultat
    }

    /// Deux pseudo-matchs par promu contre un adversaire moyen, de poids fixe :
    /// ils pèsent au début de saison, puis s'effacent devant les vrais matchs.
    static func pseudoMatchsPromus(_ promus: [String], parametres p: ParametresModele) -> [MatchPondere] {
        let baseLambda = exp(ModeleForces.baseLogDepart)
        let lambdaAttaque = baseLambda * exp(p.penaliteAttaquePromu)
        let lambdaDefense = baseLambda * exp(p.penaliteDefensePromu)
        return promus.flatMap { t in
            [MatchPondere(domicile: t, exterieur: adversaireMoyen,
                          observationDomicile: lambdaAttaque, observationExterieur: lambdaDefense,
                          butsDomicile: nil, butsExterieur: nil, poids: poidsPseudoPromu),
             MatchPondere(domicile: adversaireMoyen, exterieur: t,
                          observationDomicile: lambdaDefense, observationExterieur: lambdaAttaque,
                          butsDomicile: nil, butsExterieur: nil, poids: poidsPseudoPromu)]
        }
    }
}

/// Match de l'historique prêt pour le modèle : jour et buts attendus implicites
/// des cotes calculés une fois pour toutes (la résolution est le plus long).
struct MatchHistoriquePrepare {
    let saison: String
    let jour: Int
    let domicile: String
    let exterieur: String
    let butsDomicile: Int
    let butsExterieur: Int
    /// Probabilités 1/N/2 implicites des cotes, marge retirée.
    let probabilitesMarche: [Double]?
    let lambdasMarche: (Double, Double)?
    /// Même chose d'après les cotes d'ouverture : marché connu au moment du pari.
    let probabilitesMarcheOuverture: [Double]?
    /// Cote moyenne du marché avant le match : cote de pari de la mesure de précision.
    let cotesPari: [Double]?

    var issue: Int { butsDomicile > butsExterieur ? 0 : butsDomicile == butsExterieur ? 1 : 2 }

    /// Matchs triés par date.
    static func preparer(_ h: Historique) -> [MatchHistoriquePrepare] {
        h.matches.compactMap { m -> MatchHistoriquePrepare? in
            guard let jour = m.jour else { return nil }
            let p = m.odds.map { Cotes.probabilitesImplicites($0).map { $0 / 100 } }
            return MatchHistoriquePrepare(saison: m.season, jour: jour, domicile: m.home, exterieur: m.away,
                                          butsDomicile: m.homeGoals, butsExterieur: m.awayGoals,
                                          probabilitesMarche: p, lambdasMarche: p.map { Cotes.lambdasMarche($0) },
                                          probabilitesMarcheOuverture: m.oddsOpen.map { Cotes.probabilitesImplicites($0).map { $0 / 100 } },
                                          cotesPari: m.oddsAvg)
        }
        .sorted { ($0.jour, $0.domicile) < ($1.jour, $1.domicile) }
    }
}

// MARK: - Classements

struct LigneClassement: Identifiable {
    var rang = 0
    let equipe: String
    var joues = 0
    var gagnes = 0
    var nuls = 0
    var perdus = 0
    var butsPour = 0
    var butsContre = 0
    var points = 0

    var id: String { equipe }
    var difference: Int { butsPour - butsContre }
}

struct LigneXPoints: Identifiable {
    var rang = 0
    let equipe: String
    var joues = 0
    var xgPour = 0.0
    var xgContre = 0.0
    var xPoints = 0.0
    var pointsReels = 0

    var id: String { equipe }
    var xgDifference: Double { xgPour - xgContre }
}

enum CritereClassement: String, CaseIterable, Identifiable {
    case general, domicile, exterieur, top9, bottom9, xPoints

    var id: String { rawValue }

    var titre: String {
        switch self {
        case .general:   return "Général"
        case .domicile:  return "Domicile"
        case .exterieur: return "Extérieur"
        case .top9:      return "Contre le top 9"
        case .bottom9:   return "Contre le bottom 9"
        case .xPoints:   return "Aux xPoints"
        }
    }
}

enum Classements {

    /// Points, diff. de buts, buts marqués ; l'ordre de la saison départage le reste.
    private static func trier(_ lignes: [LigneClassement]) -> [LigneClassement] {
        let ordonnees = lignes.enumerated().sorted { x, y in
            let a = x.element, b = y.element
            if a.points != b.points { return a.points > b.points }
            if a.difference != b.difference { return a.difference > b.difference }
            if a.butsPour != b.butsPour { return a.butsPour > b.butsPour }
            return x.offset < y.offset
        }.map(\.element)
        return ordonnees.enumerated().map { i, l in
            var r = l
            r.rang = i + 1
            return r
        }
    }

    private static func ajouter(_ l: inout LigneClassement, pour: Int, contre: Int) {
        l.joues += 1
        l.butsPour += pour
        l.butsContre += contre
        if pour > contre { l.gagnes += 1; l.points += 3 }
        else if pour == contre { l.nuls += 1; l.points += 1 }
        else { l.perdus += 1 }
    }

    /// Classement réel, indépendant du modèle.
    static func general(_ ligue: Ligue) -> [LigneClassement] {
        filtre(ligue) { _, _ in true }
    }

    static func rangs(_ ligue: Ligue) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: general(ligue).map { ($0.equipe, $0.rang) })
    }

    /// Ne compte, pour chaque équipe, que les matchs retenus par `retenir(match, équipe)`.
    static func filtre(_ ligue: Ligue, _ retenir: (Match, String) -> Bool) -> [LigneClassement] {
        var lignes = ligue.equipes.map { LigneClassement(equipe: $0) }
        var index: [String: Int] = [:]
        for (i, e) in ligue.equipes.enumerated() { index[e] = i }
        for m in ligue.matchsJoues {
            guard let h = m.butsDomicile, let a = m.butsExterieur else { continue }
            if retenir(m, m.domicile), let i = index[m.domicile] { ajouter(&lignes[i], pour: h, contre: a) }
            if retenir(m, m.exterieur), let i = index[m.exterieur] { ajouter(&lignes[i], pour: a, contre: h) }
        }
        return trier(lignes)
    }

    static func domicile(_ ligue: Ligue) -> [LigneClassement] {
        filtre(ligue) { m, e in m.domicile == e }
    }

    static func exterieur(_ ligue: Ligue) -> [LigneClassement] {
        filtre(ligue) { m, e in m.exterieur == e }
    }

    /// Contre les 9 premiers (`top9`) ou les autres, d'après le classement actuel.
    static func contreGroupe(_ ligue: Ligue, top9: Bool) -> [LigneClassement] {
        let rangs = rangs(ligue)
        return filtre(ligue) { m, e in
            let adversaire = m.domicile == e ? m.exterieur : m.domicile
            guard let r = rangs[adversaire] else { return false }
            return top9 ? r <= 9 : r >= 10
        }
    }

    /// Points « attendus » d'après les xG (le score sert de repli sans xG).
    static func xPoints(_ ligue: Ligue) -> [LigneXPoints] {
        var lignes = ligue.equipes.map { LigneXPoints(equipe: $0) }
        var index: [String: Int] = [:]
        for (i, e) in ligue.equipes.enumerated() { index[e] = i }
        for m in ligue.matchsJoues {
            guard let bh = m.butsDomicile, let ba = m.butsExterieur,
                  let i = index[m.domicile], let j = index[m.exterieur] else { continue }
            let hxg = m.xgDomicile ?? Double(bh)
            let axg = m.xgExterieur ?? Double(ba)
            let p = Modele.probabilitesXg(hxg, axg)
            lignes[i].joues += 1
            lignes[i].xgPour += hxg
            lignes[i].xgContre += axg
            lignes[i].xPoints += 3 * p.p1 + p.pN
            lignes[j].joues += 1
            lignes[j].xgPour += axg
            lignes[j].xgContre += hxg
            lignes[j].xPoints += 3 * p.p2 + p.pN
        }
        let reels = Dictionary(uniqueKeysWithValues: general(ligue).map { ($0.equipe, $0.points) })
        let triees = lignes.enumerated().sorted { x, y in
            x.element.xPoints != y.element.xPoints ? x.element.xPoints > y.element.xPoints : x.offset < y.offset
        }.map(\.element)
        return triees.enumerated().map { i, l in
            var r = l
            r.rang = i + 1
            r.pointsReels = reels[l.equipe] ?? 0
            return r
        }
    }
}

// MARK: - Analyse d'une équipe

enum ResultatMatch: String {
    case victoire = "V", nul = "N", defaite = "D"
}

struct MatchEquipe: Identifiable {
    let journee: Int
    let adversaire: String
    let aDomicile: Bool
    let joue: Bool
    let butsPour: Int?
    let butsContre: Int?

    var id: Int { journee }

    var resultat: ResultatMatch? {
        guard let p = butsPour, let c = butsContre else { return nil }
        return p > c ? .victoire : (p == c ? .nul : .defaite)
    }
}

struct BilanPartiel {
    var joues = 0
    var gagnes = 0
    var nuls = 0
    var perdus = 0
    var butsPour = 0
    var butsContre = 0

    var pointsParMatch: Double { joues > 0 ? Double(gagnes * 3 + nuls) / Double(joues) : 0 }
    var butsPourParMatch: Double { joues > 0 ? Double(butsPour) / Double(joues) : 0 }
    var butsContreParMatch: Double { joues > 0 ? Double(butsContre) / Double(joues) : 0 }

    mutating func ajouter(_ pour: Int, _ contre: Int) {
        joues += 1
        butsPour += pour
        butsContre += contre
        if pour > contre { gagnes += 1 } else if pour == contre { nuls += 1 } else { perdus += 1 }
    }
}

enum AnalyseEquipe {

    /// Rang de chaque équipe après chaque journée ayant au moins un match joué.
    static func historiqueRangs(_ ligue: Ligue) -> [String: [(journee: Int, rang: Int)]] {
        let equipes = ligue.equipes
        var pts: [String: Int] = [:], bp: [String: Int] = [:], bc: [String: Int] = [:]
        var historique: [String: [(journee: Int, rang: Int)]] = [:]
        for e in equipes { pts[e] = 0; bp[e] = 0; bc[e] = 0; historique[e] = [] }
        for j in Set(ligue.matches.map(\.journee)).sorted() {
            let joues = ligue.matchs(journee: j).filter(\.joue)
            guard !joues.isEmpty else { continue }
            for m in joues {
                guard let h = m.butsDomicile, let a = m.butsExterieur else { continue }
                bp[m.domicile, default: 0] += h; bc[m.domicile, default: 0] += a
                bp[m.exterieur, default: 0] += a; bc[m.exterieur, default: 0] += h
                if h > a { pts[m.domicile, default: 0] += 3 }
                else if h == a { pts[m.domicile, default: 0] += 1; pts[m.exterieur, default: 0] += 1 }
                else { pts[m.exterieur, default: 0] += 3 }
            }
            let ordre = equipes.enumerated().sorted { x, y in
                let a = x.element, b = y.element
                let pa = pts[a] ?? 0, pb = pts[b] ?? 0
                if pa != pb { return pa > pb }
                let da = (bp[a] ?? 0) - (bc[a] ?? 0), db = (bp[b] ?? 0) - (bc[b] ?? 0)
                if da != db { return da > db }
                if bp[a] != bp[b] { return (bp[a] ?? 0) > (bp[b] ?? 0) }
                return x.offset < y.offset
            }.map(\.element)
            for (i, e) in ordre.enumerated() { historique[e]?.append((j, i + 1)) }
        }
        return historique
    }

    static func calendrier(_ ligue: Ligue, _ equipe: String) -> [MatchEquipe] {
        ligue.matches
            .filter { $0.domicile == equipe || $0.exterieur == equipe }
            .enumerated()
            .sorted { $0.element.journee != $1.element.journee ? $0.element.journee < $1.element.journee : $0.offset < $1.offset }
            .map(\.element)
            .map { m in
                let dom = m.domicile == equipe
                return MatchEquipe(journee: m.journee, adversaire: dom ? m.exterieur : m.domicile, aDomicile: dom,
                                   joue: m.joue, butsPour: dom ? m.butsDomicile : m.butsExterieur,
                                   butsContre: dom ? m.butsExterieur : m.butsDomicile)
            }
    }

    static func formeRecente(_ ligue: Ligue, _ equipe: String, n: Int = 5) -> [MatchEquipe] {
        Array(calendrier(ligue, equipe).filter(\.joue).suffix(n))
    }

    /// Bilans à domicile, à l'extérieur, contre le top 9 et contre les autres.
    static func bilans(_ ligue: Ligue, _ equipe: String)
        -> (domicile: BilanPartiel, exterieur: BilanPartiel, top9: BilanPartiel, bottom9: BilanPartiel) {
        let rangs = Classements.rangs(ligue)
        var dom = BilanPartiel(), ext = BilanPartiel(), top = BilanPartiel(), bas = BilanPartiel()
        for m in calendrier(ligue, equipe) where m.joue {
            guard let p = m.butsPour, let c = m.butsContre else { continue }
            if m.aDomicile { dom.ajouter(p, c) } else { ext.ajouter(p, c) }
            guard let r = rangs[m.adversaire] else { continue }
            if r <= 9 { top.ajouter(p, c) } else { bas.ajouter(p, c) }
        }
        return (dom, ext, top, bas)
    }
}

// MARK: - Monte Carlo (forces statiques issues du modèle)

/// Générateur xoshiro256** : rapide et indépendant d'un état global.
struct GenerateurAleatoire: RandomNumberGenerator {
    private var s: (UInt64, UInt64, UInt64, UInt64)

    init(graine: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        var z = graine
        func splitmix() -> UInt64 {
            z &+= 0x9E37_79B9_7F4A_7C15
            var r = z
            r = (r ^ (r >> 30)) &* 0xBF58_476D_1CE4_E5B9
            r = (r ^ (r >> 27)) &* 0x94D0_49BB_1331_11EB
            return r ^ (r >> 31)
        }
        s = (splitmix(), splitmix(), splitmix(), splitmix())
    }

    private static func rotl(_ x: UInt64, _ k: UInt64) -> UInt64 { (x << k) | (x >> (64 - k)) }

    mutating func next() -> UInt64 {
        let resultat = Self.rotl(s.1 &* 5, 7) &* 9
        let t = s.1 << 17
        s.2 ^= s.0; s.3 ^= s.1; s.1 ^= s.2; s.0 ^= s.3
        s.2 ^= t
        s.3 = Self.rotl(s.3, 45)
        return resultat
    }

    /// Réel uniforme dans [0, 1).
    mutating func uniforme() -> Double { Double(next() >> 11) * 0x1.0p-53 }
}

struct ResultatSimulation {
    /// Probabilité (%) de finir à chaque place, par équipe.
    let probabilitesPlaces: [String: [Double]]
    let pointsMoyens: [String: Double]
    let simulations: Int
}

enum MonteCarlo {
    static func simuler(ligue: Ligue, modele: ModeleForces, simulations: Int,
                        annule: () -> Bool = { false }) -> ResultatSimulation? {
        let equipes = ligue.equipes
        let n = equipes.count
        var index: [String: Int] = [:]
        for (i, e) in equipes.enumerated() { index[e] = i }
        let base = Classements.filtre(ligue) { _, _ in true }
        var basePoints = [Int](repeating: 0, count: n)
        var baseBP = [Int](repeating: 0, count: n)
        var baseBC = [Int](repeating: 0, count: n)
        for l in base {
            guard let i = index[l.equipe] else { continue }
            basePoints[i] = l.points; baseBP[i] = l.butsPour; baseBC[i] = l.butsContre
        }

        // Une matrice de scores (cumulée) par match à jouer, partagée par toutes les simulations.
        let aJouer = ligue.matchsAJouer.enumerated()
            .sorted { $0.element.journee != $1.element.journee ? $0.element.journee < $1.element.journee : $0.offset < $1.offset }
            .map(\.element)
        let t = Modele.tailleGrille
        let tirages: [(h: Int, a: Int, cumul: [Double])] = aJouer.compactMap { m in
            guard let h = index[m.domicile], let a = index[m.exterieur] else { return nil }
            let (lh, la) = modele.lambdas(m.domicile, m.exterieur)
            var cumul = Modele.matriceScores(lh, la, rho: modele.rho)
            for k in 1..<cumul.count { cumul[k] += cumul[k - 1] }
            return (h, a, cumul)
        }

        var comptes = [[Int]](repeating: [Int](repeating: 0, count: n), count: n)
        var sommePoints = [Double](repeating: 0, count: n)
        var rng = GenerateurAleatoire()
        var points = basePoints, bp = baseBP, bc = baseBC
        var ordre = Array(0..<n)

        for s in 0..<simulations {
            if s % 1000 == 0, annule() { return nil }
            points = basePoints; bp = baseBP; bc = baseBC
            for tirage in tirages {
                let r = rng.uniforme()
                // Premier indice dont le cumul atteint r (searchsorted, côté gauche).
                var bas = 0, haut = tirage.cumul.count - 1
                while bas < haut {
                    let milieu = (bas + haut) / 2
                    if tirage.cumul[milieu] < r { bas = milieu + 1 } else { haut = milieu }
                }
                let hg = bas / t, ag = bas % t
                bp[tirage.h] += hg; bc[tirage.h] += ag
                bp[tirage.a] += ag; bc[tirage.a] += hg
                if hg > ag { points[tirage.h] += 3 }
                else if hg == ag { points[tirage.h] += 1; points[tirage.a] += 1 }
                else { points[tirage.a] += 3 }
            }
            ordre = Array(0..<n)
            ordre.sort { x, y in
                if points[x] != points[y] { return points[x] > points[y] }
                let dx = bp[x] - bc[x], dy = bp[y] - bc[y]
                if dx != dy { return dx > dy }
                if bp[x] != bp[y] { return bp[x] > bp[y] }
                return x < y
            }
            for (rang, i) in ordre.enumerated() { comptes[i][rang] += 1 }
            for i in 0..<n { sommePoints[i] += Double(points[i]) }
        }

        var probabilites: [String: [Double]] = [:]
        var moyennes: [String: Double] = [:]
        for (i, e) in equipes.enumerated() {
            probabilites[e] = comptes[i].map { Double($0) / Double(max(simulations, 1)) * 100 }
            moyennes[e] = sommePoints[i] / Double(max(simulations, 1))
        }
        return ResultatSimulation(probabilitesPlaces: probabilites, pointsMoyens: moyennes, simulations: simulations)
    }
}

// MARK: - Cotes

enum Cotes {
    /// Probabilités implicites (%) d'un bookmaker, marge retirée proportionnellement.
    static func probabilitesImplicites(_ cotes: [Double]) -> [Double] {
        let brut = cotes.map { 1 / $0 }
        let somme = brut.reduce(0, +)
        return brut.map { $0 / somme * 100 }
    }

    /// Probabilités du marché : cotes de référence du CSV (clôture Pinnacle de
    /// préférence), sinon consensus des bookmakers saisis (marge retirée livre
    /// par livre, puis moyenne).
    /// Probabilités du marché au moment du pari : cotes d'ouverture du CSV, à
    /// défaut `probabilitesMarche` (clôture, connue après coup pour un match joué).
    static func probabilitesMarchePari(_ m: Match) -> [Double]? {
        if let o = m.cotesOuverture, o.count == 3 { return probabilitesImplicites(o).map { $0 / 100 } }
        return probabilitesMarche(m)
    }

    static func probabilitesMarche(_ m: Match) -> [Double]? {
        if let r = m.cotesReference, r.count == 3 { return probabilitesImplicites(r).map { $0 / 100 } }
        let livres = m.livres
        guard !livres.isEmpty else { return nil }
        var p = [0.0, 0.0, 0.0]
        for l in livres {
            let imp = probabilitesImplicites(l.cotes)
            for i in 0..<3 { p[i] += imp[i] / 100 }
        }
        p = p.map { $0 / Double(livres.count) }
        let somme = p.reduce(0, +)
        return p.map { $0 / somme }
    }

    /// Inverse le modèle de score : (λ dom., λ ext.) dont le Poisson indépendant
    /// (ρ = 0) reproduit l'écart p1 - p2 et la probabilité de nul. Newton 2D,
    /// jacobienne par différences finies.
    static func lambdasMarche(_ p: [Double], iterations: Int = 40) -> (Double, Double) {
        let cibleEcart = p[0] - p[2], cibleNul = p[1]
        let bas = log(0.05), haut = log(6.0)
        let eps = 1e-5
        func residu(_ u: Double, _ v: Double) -> (Double, Double) {
            let r = Modele.issues(Modele.matriceScores(exp(u), exp(v), rho: 0))
            return (r.p1 - r.p2 - cibleEcart, r.pN - cibleNul)
        }
        var u = log(1.5), v = log(1.15)
        for _ in 0..<iterations {
            let (f1, f2) = residu(u, v)
            if max(abs(f1), abs(f2)) < 1e-9 { break }
            let (a1, a2) = residu(u + eps, v)
            let (b1, b2) = residu(u, v + eps)
            let j11 = (a1 - f1) / eps, j21 = (a2 - f2) / eps
            let j12 = (b1 - f1) / eps, j22 = (b2 - f2) / eps
            var det = j11 * j22 - j12 * j21
            if abs(det) < 1e-12 { det = 1e-12 }
            let du = min(max((-f1 * j22 + f2 * j12) / det, -0.5), 0.5)
            let dv = min(max((-j11 * f2 + j21 * f1) / det, -0.5), 0.5)
            u = min(max(u + du, bas), haut)
            v = min(max(v + dv, bas), haut)
        }
        return (exp(u), exp(v))
    }

    /// Cote équivalente d'une double chance (A ou B), mise répartie pour égaliser le gain.
    static func combinee(_ a: Double, _ b: Double) -> Double { a * b / (a + b) }

    /// Répartition de la mise totale entre A et B.
    static func repartition(_ a: Double, _ b: Double, mise: Double) -> (Double, Double) {
        let partA = b / (a + b)
        return (mise * partA, mise * (1 - partA))
    }
}

// MARK: - Backtest walk-forward

struct ScoresPrevision {
    let logLoss: Double
    let rps: Double
    let brier: Double
}

struct LigneBacktest: Identifiable {
    let libelle: String
    let marketAlpha: Double?
    let scores: ScoresPrevision
    let logLossMoitie1: Double?
    let logLossMoitie2: Double?
    let nulsPredits: Double
    var poidsModeleOptimal: Double?
    var reglageActuel = false

    var id: String { libelle }
}

struct PointCalibration: Identifiable {
    let predite: Double
    let observee: Double
    let effectif: Int
    var id: Double { predite }
}

struct ResultatBacktest {
    let n: Int
    let nulsObserves: Double
    let moitie: Int
    let nJournees: Int
    let lignes: [LigneBacktest]
    let calibration: [(libelle: String, points: [PointCalibration])]
}

enum Backtest {

    /// Scores moyens (plus bas = meilleur) : log-loss, RPS et Brier ; issues 0 = 1, 1 = N, 2 = 2.
    static func scores(_ p: [[Double]], _ issues: [Int]) -> ScoresPrevision {
        var ll = 0.0, rps = 0.0, brier = 0.0
        for (k, o) in issues.enumerated() {
            ll -= log(max(p[k][o], 1e-12))
            var cumP = 0.0, cumO = 0.0, r = 0.0
            for i in 0..<2 {
                cumP += p[k][i]
                cumO += i == o ? 1 : 0
                r += (cumP - cumO) * (cumP - cumO)
            }
            rps += r / 2
            for i in 0..<3 {
                let d = p[k][i] - (i == o ? 1 : 0)
                brier += d * d
            }
        }
        let n = Double(max(issues.count, 1))
        return ScoresPrevision(logLoss: ll / n, rps: rps / n, brier: brier / n)
    }

    /// Mélange logarithmique : p ∝ pA^w · pB^(1-w).
    static func melange(_ a: [[Double]], _ b: [[Double]], poids w: Double) -> [[Double]] {
        zip(a, b).map { pa, pb in
            let p = (0..<3).map { pow(max(pa[$0], 1e-12), w) * pow(max(pb[$0], 1e-12), 1 - w) }
            let s = p.reduce(0, +)
            return p.map { $0 / s }
        }
    }

    /// Courbe de fiabilité : les 3 probabilités de chaque match par tranche de 10 %.
    static func calibration(_ p: [[Double]], _ issues: [Int], tranches: Int = 10) -> [PointCalibration] {
        var somme = [Double](repeating: 0, count: tranches)
        var touches = [Double](repeating: 0, count: tranches)
        var effectif = [Int](repeating: 0, count: tranches)
        for (k, o) in issues.enumerated() {
            for i in 0..<3 {
                let b = min(Int(p[k][i] * Double(tranches)), tranches - 1)
                somme[b] += p[k][i]
                touches[b] += i == o ? 1 : 0
                effectif[b] += 1
            }
        }
        return (0..<tranches).compactMap { b in
            effectif[b] > 0
                ? PointCalibration(predite: somme[b] / Double(effectif[b]), observee: touches[b] / Double(effectif[b]),
                                   effectif: effectif[b])
                : nil
        }
    }

    /// Pour chaque journée, modèle ajusté sur ce qui était connu avant elle puis
    /// prévision de ses matchs ; une passe par β, comparée au marché (matchs
    /// joués, avec cotes, hors forfait). nil sans match évaluable.
    static func walkForward(ligue: Ligue, historique: [MatchHistoriquePrepare] = [],
                            debutSaison: Int, parametres: ParametresModele = .depart,
                            annule: () -> Bool = { false }) -> ResultatBacktest? {
        let alphas = [0.0, 0.5, parametres.marketAlpha, 1.0]
        let matchs = ligue.matchsJoues.filter { !$0.forfait && Cotes.probabilitesMarche($0) != nil }.enumerated()
            .sorted { $0.element.journee != $1.element.journee ? $0.element.journee < $1.element.journee : $0.offset < $1.offset }
            .map(\.element)
        guard !matchs.isEmpty else { return nil }
        let issues = matchs.map { m -> Int in
            switch m.issue {
            case .domicile?: return 0
            case .nul?: return 1
            default: return 2
            }
        }
        let pMarche = matchs.map { Cotes.probabilitesMarche($0) ?? [1.0 / 3, 1.0 / 3, 1.0 / 3] }
        let moitie = ligue.nJournees / 2
        let premiere = matchs.map { $0.journee <= moitie }

        func ligne(_ libelle: String, _ p: [[Double]], alpha: Double?) -> LigneBacktest {
            func logLoss(_ selection: Bool) -> Double? {
                let idx = premiere.indices.filter { premiere[$0] == selection }
                guard !idx.isEmpty else { return nil }
                return scores(idx.map { p[$0] }, idx.map { issues[$0] }).logLoss
            }
            return LigneBacktest(libelle: libelle, marketAlpha: alpha, scores: scores(p, issues),
                                 logLossMoitie1: logLoss(true), logLossMoitie2: logLoss(false),
                                 nulsPredits: p.map { $0[1] }.reduce(0, +) / Double(p.count))
        }

        var lignes = [ligne("Marché (cotes de référence, marge retirée)", pMarche, alpha: nil)]
        var courbes: [(libelle: String, points: [PointCalibration])] = [("Marché", calibration(pMarche, issues))]
        let journees = Array(Set(matchs.map(\.journee))).sorted()
        let poids = (0...10).map { Double($0) / 10 }

        for alpha in Array(Set(alphas)).sorted() {
            var pModele = [[Double]](repeating: [0, 0, 0], count: matchs.count)
            for j in journees {
                if annule() { return nil }
                var p = parametres
                p.marketAlpha = alpha
                let modele = Modele.construire(ligue: ligue, historique: historique,
                                               debutSaison: debutSaison, journeeReference: j, parametres: p)
                for (k, m) in matchs.enumerated() where m.journee == j {
                    pModele[k] = modele.probas(m.domicile, m.exterieur).triplet
                }
            }
            var libelle = "Modèle β = \(Format.nombre(alpha, decimales: 2, fixe: true))"
            if alpha == 0 { libelle += " (résultats seuls)" }
            else if alpha == 1 { libelle += " (cotes seules)" }
            var l = ligne(libelle, pModele, alpha: alpha)
            if alpha == parametres.marketAlpha {
                l.reglageActuel = true
                courbes.append(("Modèle β = \(Format.nombre(alpha, decimales: 2, fixe: true))", calibration(pModele, issues)))
            }
            // Poids du modèle mélangé aux cotes du match : 0 = aucune information en plus.
            let pertes = poids.map { scores(melange(pModele, pMarche, poids: $0), issues).logLoss }
            if let meilleur = pertes.indices.min(by: { pertes[$0] < pertes[$1] }) {
                l.poidsModeleOptimal = poids[meilleur]
            }
            lignes.append(l)
        }

        return ResultatBacktest(n: matchs.count,
                                nulsObserves: Double(issues.filter { $0 == 1 }.count) / Double(issues.count),
                                moitie: moitie, nJournees: ligue.nJournees, lignes: lignes, calibration: courbes)
    }
}

// MARK: - Calibration sur l'historique

struct EssaiCalibration: Identifiable {
    let parametre: String
    let valeur: String
    let logLoss: Double
    let retenu: Bool

    var id: String { parametre + valeur }
}

struct SaisonCalibration: Identifiable {
    let saison: String
    let n: Int
    let logLossDepart: Double
    let logLossCalibre: Double
    let logLossMarche: Double

    var id: String { saison }
}

struct ResultatCalibration {
    let n: Int
    let parametres: ParametresModele
    /// Valeurs de départ (avant calibration), pour mesurer le gain.
    let depart: ScoresPrevision
    let calibre: ScoresPrevision
    let marche: ScoresPrevision
    /// Poids du modèle calibré mélangé aux cotes du match (0 = rien de plus que les bookmakers).
    let poidsModeleOptimal: Double
    let essais: [EssaiCalibration]
    let saisons: [SaisonCalibration]
}

/// Choix des hyperparamètres par walk-forward sur les saisons passées : chaque
/// saison (sauf la première, qui ne sert qu'à démarrer) est prédite bloc par
/// bloc, le modèle ne voyant que les matchs antérieurs. Recherche coordonnée
/// depuis `ParametresModele.depart` : β, puis ξ, puis ridge, puis pénalité promu
/// (0, ½, 1 ou 1,5 fois celle observée sur l'historique), chacun à la meilleure
/// log-loss.
enum Calibration {
    static let grilleBeta = [0.0, 0.25, 0.5, 0.75, 1.0]
    static let grilleXi = [0.001, 0.002, 0.0035, 0.005, 0.0065, 0.008, 0.01, 0.0135, 0.018]
    static let grilleRidge = [0.02, 0.04, 0.08, 0.15, 0.3]
    static let facteursPromus = [0.0, 0.5, 1.0, 1.5]
    /// Un bloc regroupe les matchs des 4 jours suivant son premier match (une journée).
    static let dureeBloc = 3

    struct Previsions {
        var modele: [[Double]] = []
        var marche: [[Double]] = []
        /// Marché d'après les cotes d'ouverture ; nil si le CSV n'en avait pas.
        var marcheOuverture: [[Double]?] = []
        var issues: [Int] = []
        var saisons: [String] = []
        var cotesPari: [[Double]?] = []

        mutating func ajouter(_ autre: Previsions) {
            modele += autre.modele
            marche += autre.marche
            marcheOuverture += autre.marcheOuverture
            issues += autre.issues
            saisons += autre.saisons
            cotesPari += autre.cotesPari
        }
    }

    /// Prévisions walk-forward des matchs avec cotes ; saisons calculées en parallèle.
    static func previsions(_ h: [MatchHistoriquePrepare], parametres p: ParametresModele,
                           annule: () -> Bool = { false }) -> Previsions? {
        let saisons = Array(Set(h.map(\.saison))).sorted()
        guard saisons.count >= 2 else { return nil }
        var parSaison = [Previsions](repeating: Previsions(), count: saisons.count - 1)
        let verrou = NSLock()
        DispatchQueue.concurrentPerform(iterations: saisons.count - 1) { k in
            let r = previsions(saison: saisons[k + 1], precedente: saisons[k], h, p, annule)
            verrou.lock()
            parSaison[k] = r
            verrou.unlock()
        }
        if annule() { return nil }
        var total = Previsions()
        parSaison.forEach { total.ajouter($0) }
        return total.issues.isEmpty ? nil : total
    }

    private static func previsions(saison: String, precedente: String, _ h: [MatchHistoriquePrepare],
                                   _ p: ParametresModele, _ annule: () -> Bool) -> Previsions {
        var r = Previsions()
        let matchs = h.filter { $0.saison == saison }
        guard let debut = matchs.first?.jour, let fin = matchs.last?.jour else { return r }
        let equipes = Set(matchs.flatMap { [$0.domicile, $0.exterieur] })
        let anciennes = Set(h.filter { $0.saison == precedente }.flatMap { [$0.domicile, $0.exterieur] })
        let pseudo = Modele.pseudoMatchsPromus(equipes.subtracting(anciennes).sorted(), parametres: p)
        // Univers fixe sur toute la saison : chaque bloc repart des forces du précédent.
        let univers = equipes.union((Modele.ponderes(h, avant: fin + 1, reference: debut, parametres: p) + pseudo)
            .flatMap { [$0.domicile, $0.exterieur] })
        var modele = ModeleForces(equipes: univers.sorted())

        var i = 0
        while i < matchs.count, !annule() {
            let debutBloc = matchs[i].jour
            var j = i
            while j < matchs.count, matchs[j].jour <= debutBloc + dureeBloc { j += 1 }
            modele.ajuster(Modele.ponderes(h, avant: debutBloc, reference: debutBloc, parametres: p) + pseudo,
                           ridge: p.ridge)
            for m in matchs[i..<j] {
                guard let pm = m.probabilitesMarche else { continue }
                r.modele.append(modele.probas(m.domicile, m.exterieur).triplet)
                r.marche.append(pm)
                r.marcheOuverture.append(m.probabilitesMarcheOuverture)
                r.issues.append(m.issue)
                r.saisons.append(saison)
                r.cotesPari.append(m.cotesPari)
            }
            i = j
        }
        return r
    }

    /// Écart moyen des promus à la moyenne de leur saison (attaque, défense),
    /// d'après un ajustement sur la saison complète, sans pondération temporelle.
    static func penalitesObservees(_ h: [MatchHistoriquePrepare], parametres p: ParametresModele) -> (Double, Double)? {
        let saisons = Array(Set(h.map(\.saison))).sorted()
        var sommeA = 0.0, sommeD = 0.0, n = 0
        for k in saisons.indices.dropFirst() {
            let matchs = h.filter { $0.saison == saisons[k] }
            guard let fin = matchs.last?.jour else { continue }
            let equipes = Array(Set(matchs.flatMap { [$0.domicile, $0.exterieur] })).sorted()
            let anciennes = Set(h.filter { $0.saison == saisons[k - 1] }.flatMap { [$0.domicile, $0.exterieur] })
            let promus = equipes.filter { !anciennes.contains($0) }
            guard !promus.isEmpty else { continue }
            var q = p
            q.xi = 0
            var modele = ModeleForces(equipes: equipes)
            modele.ajuster(Modele.ponderes(matchs, avant: fin + 1, reference: fin, parametres: q), ridge: p.ridge)
            let moyA = modele.attaque.reduce(0, +) / Double(equipes.count)
            let moyD = modele.defense.reduce(0, +) / Double(equipes.count)
            for t in promus {
                guard let i = modele.index[t] else { continue }
                sommeA += modele.attaque[i] - moyA
                sommeD += modele.defense[i] - moyD
                n += 1
            }
        }
        guard n > 0 else { return nil }
        return (min(max(sommeA / Double(n), -1), 1), min(max(sommeD / Double(n), -1), 1))
    }

    /// nil si l'historique a moins de deux saisons ou si le calcul est annulé.
    static func calibrer(_ h: [MatchHistoriquePrepare], progression: (Double) -> Void = { _ in },
                         annule: () -> Bool = { false }) -> ResultatCalibration? {
        let total = Double(grilleBeta.count + grilleXi.count + grilleRidge.count + facteursPromus.count)
        var faits = 0.0
        var cache: [ParametresModele: Previsions] = [:]
        func evaluer(_ q: ParametresModele) -> Previsions? {
            if let r = cache[q] { return r }
            let r = previsions(h, parametres: q, annule: annule)
            cache[q] = r
            return r
        }

        var meilleur = ParametresModele.depart
        var essais: [EssaiCalibration] = []
        func balayer(_ nom: String, _ variantes: [(libelle: String, parametres: ParametresModele)]) -> Bool {
            var pertes: [Double] = []
            for v in variantes {
                guard let r = evaluer(v.parametres) else { return false }
                pertes.append(Backtest.scores(r.modele, r.issues).logLoss)
                faits += 1
                progression(faits / total)
            }
            guard let k = pertes.indices.min(by: { pertes[$0] < pertes[$1] }) else { return false }
            meilleur = variantes[k].parametres
            essais += variantes.indices.map {
                EssaiCalibration(parametre: nom, valeur: variantes[$0].libelle, logLoss: pertes[$0], retenu: $0 == k)
            }
            return true
        }
        func variantes(_ valeurs: [Double], decimales: Int,
                       _ modifier: (inout ParametresModele, Double) -> Void) -> [(libelle: String, parametres: ParametresModele)] {
            valeurs.map { v in
                var q = meilleur
                modifier(&q, v)
                return (Format.nombre(v, decimales: decimales), q)
            }
        }

        guard balayer("Cotes β", variantes(grilleBeta, decimales: 2) { $0.marketAlpha = $1 }),
              balayer("Décroissance ξ", variantes(grilleXi, decimales: 4) { $0.xi = $1 }),
              balayer("Ridge", variantes(grilleRidge, decimales: 3) { $0.ridge = $1 }) else { return nil }
        var promus: [(libelle: String, parametres: ParametresModele)] = []
        if let observees = penalitesObservees(h, parametres: meilleur) {
            promus = facteursPromus.map { f in
                var q = meilleur
                q.penaliteAttaquePromu = f * observees.0
                q.penaliteDefensePromu = f * observees.1
                return (f == 0 ? "aucune" : "\(Format.nombre(f, decimales: 1)) × observée (\(Format.signe(q.penaliteAttaquePromu, decimales: 2)) / "
                        + "\(Format.signe(q.penaliteDefensePromu, decimales: 2)))", q)
            }
        } else {
            promus = [("aucune (pas de promu identifiable)", meilleur)]
            faits += Double(facteursPromus.count - 1)
        }
        guard balayer("Promus", promus),
              let depart = evaluer(.depart), let calibre = evaluer(meilleur) else { return nil }

        let poids = (0...10).map { Double($0) / 10 }
        let pertes = poids.map { Backtest.scores(Backtest.melange(calibre.modele, calibre.marche, poids: $0), calibre.issues).logLoss }
        let k = pertes.indices.min { pertes[$0] < pertes[$1] } ?? 0

        let saisons = Array(Set(calibre.saisons)).sorted().map { s -> SaisonCalibration in
            let idx = calibre.saisons.indices.filter { calibre.saisons[$0] == s }
            func ll(_ p: [[Double]]) -> Double { Backtest.scores(idx.map { p[$0] }, idx.map { calibre.issues[$0] }).logLoss }
            return SaisonCalibration(saison: s, n: idx.count, logLossDepart: ll(depart.modele),
                                     logLossCalibre: ll(calibre.modele), logLossMarche: ll(calibre.marche))
        }
        return ResultatCalibration(n: calibre.issues.count, parametres: meilleur,
                                   depart: Backtest.scores(depart.modele, depart.issues),
                                   calibre: Backtest.scores(calibre.modele, calibre.issues),
                                   marche: Backtest.scores(calibre.marche, calibre.issues),
                                   poidsModeleOptimal: poids[k], essais: essais, saisons: saisons)
    }
}

// MARK: - Précision des conseils (walk-forward sur l'historique)

/// Intervalle de confiance à 95 %.
struct Intervalle: Equatable {
    let bas: Double
    let haut: Double

    /// Wilson, pour une fréquence observée.
    static func wilson(_ succes: Int, _ n: Int) -> Intervalle {
        guard n > 0 else { return Intervalle(bas: 0, haut: 1) }
        let z = 1.96, nn = Double(n), p = Double(succes) / nn
        let centre = (p + z * z / (2 * nn)) / (1 + z * z / nn)
        let demi = z * (p * (1 - p) / nn + z * z / (4 * nn * nn)).squareRoot() / (1 + z * z / nn)
        return Intervalle(bas: max(0, centre - demi), haut: min(1, centre + demi))
    }
}

/// Quand le modèle annonce une probabilité de cette tranche, fréquence réelle de l'issue.
struct TrancheFiabilite: Identifiable {
    let bas: Double
    let haut: Double
    let predite: Double
    let observee: Double
    let n: Int
    let ic: Intervalle

    var id: Double { bas }
    func contient(_ p: Double) -> Bool { p >= bas && (p < haut || haut >= 1) }
}

/// Résultat de paris d'un euro chacun.
struct BilanParis {
    enum Verdict { case avantage, incertain, perte }

    let n: Int
    let gagnes: Int
    let coteMoyenne: Double
    /// Gain moyen par euro misé.
    let roi: Double
    /// Sur le ROI, approximation normale.
    let ic: Intervalle

    var tauxReussite: Double { n > 0 ? Double(gagnes) / Double(n) : 0 }
    /// Avantage démontré (IC au-dessus de 0), perte démontrée (en dessous) ou rien de démontré.
    var verdict: Verdict { n < 2 ? .incertain : ic.bas > 0 ? .avantage : ic.haut < 0 ? .perte : .incertain }

    init(_ paris: [(gain: Double, cote: Double)]) {
        n = paris.count
        gagnes = paris.filter { $0.gain > 0 }.count
        let nn = Double(max(n, 1))
        coteMoyenne = paris.map(\.cote).reduce(0, +) / nn
        let moyenne = paris.map(\.gain).reduce(0, +) / nn
        let variance = n > 1 ? paris.map { ($0.gain - moyenne) * ($0.gain - moyenne) }.reduce(0, +) / Double(n - 1) : 0
        let demi = 1.96 * (variance / nn).squareRoot()
        roi = moyenne
        ic = Intervalle(bas: moyenne - demi, haut: moyenne + demi)
    }
}

struct LigneBilan: Identifiable {
    let titre: String
    let bilan: BilanParis
    var id: String { titre }
}

struct ResultatPrecision {
    let saisons: [String]
    let n: Int
    let modele: ScoresPrevision
    let marche: ScoresPrevision
    let fiabilite: [TrancheFiabilite]
    /// Règle de sélection actuelle, appliquée à la cote moyenne en ligne.
    let global: BilanParis
    let parMarche: [LigneBilan]
    let parEsperance: [LigneBilan]
    /// Bornes des tranches d'espérance (la dernière est ouverte).
    let bornesEsperance: [Double]
    /// Matchs sans cotes d'ouverture, où le mélange a dû prendre la clôture
    /// (connue après coup : résultat flatté). Réimporter l'historique les fait disparaître.
    let sansOuverture: Int

    func tranche(_ p: Double) -> TrancheFiabilite? { fiabilite.first { $0.contient(p) } }

    func bilan(esperance e: Double) -> LigneBilan? {
        guard let k = bornesEsperance.lastIndex(where: { e >= $0 }), k < parEsperance.count else { return nil }
        return parEsperance[k]
    }

    func bilan(marche: Marche) -> LigneBilan? {
        parMarche.first { $0.titre == Precision.titre(marche) }
    }
}

/// Mesure, sur les saisons passées, ce que valent les conseils : fiabilité des
/// probabilités du modèle (prévisions walk-forward, paramètres en service) et
/// résultat des paris que la règle actuelle aurait choisis à la cote moyenne
/// du marché avant le match (sans la règle des 2 buts d'avance, faute de minutes).
enum Precision {
    static let bornesEsperance = [1.0, 1.1, 1.2, 1.35]

    static func titre(_ m: Marche) -> String {
        m.estDoubleChance ? "Double chance" : m.titre
    }

    static func analyser(_ p: Calibration.Previsions, reglages r: Reglages) -> ResultatPrecision? {
        guard !p.issues.isEmpty else { return nil }
        // Mêmes probabilités que les conseils : mélange modèle / marché au poids en
        // service, marché d'ouverture (le seul connu au moment du pari).
        let probas = p.issues.indices.map {
            Paris.probabilites(modele: p.modele[$0], marche: p.marcheOuverture[$0] ?? p.marche[$0], poids: r.poidsModele)
        }
        let sansOuverture = r.poidsModele < 1 ? p.marcheOuverture.filter { $0 == nil }.count : 0

        var fiabilite: [TrancheFiabilite] = []
        for b in 0..<10 {
            let bas = Double(b) / 10, haut = Double(b + 1) / 10
            var somme = 0.0, touches = 0, n = 0
            for (k, o) in p.issues.enumerated() {
                for i in 0..<3 where probas[k][i] >= bas && (probas[k][i] < haut || b == 9) {
                    somme += probas[k][i]
                    touches += i == o ? 1 : 0
                    n += 1
                }
            }
            guard n > 0 else { continue }
            fiabilite.append(TrancheFiabilite(bas: bas, haut: haut, predite: somme / Double(n),
                                              observee: Double(touches) / Double(n), n: n,
                                              ic: Intervalle.wilson(touches, n)))
        }

        let issues: [Marche] = [.un, .nul, .deux]
        var paris: [(marche: Marche, esperance: Double, gain: Double, cote: Double)] = []
        for k in p.issues.indices {
            guard let cotes = p.cotesPari[k] else { continue }
            let opts = Paris.options(probas[k], cotes)
            let issue = issues[p.issues[k]]
            for c in Paris.candidats(opts, bornes: opts, reglages: r, manuels: [], exclus: []) {
                let gagne = c.marche == issue || c.marche.jambes.map { $0.0 == issue || $0.1 == issue } == true
                paris.append((c.marche, c.option.esperance, gagne ? c.option.cote - 1 : -1, c.option.cote))
            }
        }
        func bilan(_ l: [(marche: Marche, esperance: Double, gain: Double, cote: Double)]) -> BilanParis {
            BilanParis(l.map { ($0.gain, $0.cote) })
        }
        let marches = [Marche.un, .nul, .deux].map(titre) + ["Double chance"]
        let parMarche = marches.map { t in LigneBilan(titre: t, bilan: bilan(paris.filter { titre($0.marche) == t })) }
        let parEsperance = bornesEsperance.indices.map { k -> LigneBilan in
            let bas = bornesEsperance[k], haut = k + 1 < bornesEsperance.count ? bornesEsperance[k + 1] : .infinity
            let t = haut.isFinite ? "\(Format.nombre(bas, decimales: 2, fixe: true)) à \(Format.nombre(haut, decimales: 2, fixe: true))"
                : "≥ \(Format.nombre(bas, decimales: 2, fixe: true))"
            return LigneBilan(titre: t, bilan: bilan(paris.filter { $0.esperance >= bas && $0.esperance < haut }))
        }
        return ResultatPrecision(saisons: Array(Set(p.saisons)).sorted(), n: p.issues.count,
                                 modele: Backtest.scores(p.modele, p.issues), marche: Backtest.scores(p.marche, p.issues),
                                 fiabilite: fiabilite, global: bilan(paris), parMarche: parMarche,
                                 parEsperance: parEsperance, bornesEsperance: bornesEsperance,
                                 sansOuverture: sansOuverture)
    }
}
