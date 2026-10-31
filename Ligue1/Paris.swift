//
//  Paris.swift
//  Ligue1
//  © 2026 Stephen O'Donnell, Tanguy Labbe · GNU GPL v3 ou ultérieure (fichier LICENSE).
//
//  Simulation de paris (betting.py de l'app Python).
//
//  - Marché simple (1, N, 2) : le meilleur des trois s'il dépasse le seuil
//    d'espérance et reste dans [cote min, cote max] (cote médiane entre livres).
//  - Double chance (1N, 12, N2), cote calculée à partir des cotes simples :
//    retenue EN PLUS d'un marché simple, jamais à sa place, au-delà d'une cote
//    minimale dédiée. Son espérance ne dépasse jamais celle du meilleur des deux
//    marchés simples qui la composent.
//  - Une double chance est deux mises séparées, réglées jambe par jambe, y
//    compris pour la règle Winamax des 2 buts d'avance (jamais sur « N »).
//  - Tous les paris d'une journée partent de la même bankroll ; les résultats
//    s'appliquent ensemble en fin de journée.
//  - Paris en attente : matchs pas encore joués avec cotes, probabilité en
//    direct du modèle, sans impact sur la bankroll.
//  - Cotes : meilleure des bookmakers saisis ; à défaut, cote moyenne en ligne
//    du CSV (« Moy. en ligne »), indicative.
//  Tout est rejoué depuis le début à chaque changement.
//
import Foundation

enum MethodeMise: String, CaseIterable, Identifiable {
    case fixe, kelly, demiKelly, quartKelly

    var id: String { rawValue }

    var titre: String {
        switch self {
        case .fixe:       return "Mise fixe"
        case .kelly:      return "Kelly plein"
        case .demiKelly:  return "Demi-Kelly"
        case .quartKelly: return "Quart-Kelly"
        }
    }

    var titreCourt: String {
        switch self {
        case .fixe:       return "Mise fixe"
        case .kelly:      return "Mise Kelly"
        case .demiKelly:  return "Mise ½K"
        case .quartKelly: return "Mise ¼K"
        }
    }
}

/// Une valeur par méthode de mise.
struct ParMethode: Equatable {
    var fixe = 0.0
    var kelly = 0.0
    var demiKelly = 0.0
    var quartKelly = 0.0

    init(_ v: Double = 0) {
        fixe = v; kelly = v; demiKelly = v; quartKelly = v
    }

    subscript(m: MethodeMise) -> Double {
        get {
            switch m {
            case .fixe: return fixe
            case .kelly: return kelly
            case .demiKelly: return demiKelly
            case .quartKelly: return quartKelly
            }
        }
        set {
            switch m {
            case .fixe: fixe = newValue
            case .kelly: kelly = newValue
            case .demiKelly: demiKelly = newValue
            case .quartKelly: quartKelly = newValue
            }
        }
    }
}

/// Probabilité, cote et espérance d'un marché.
struct OptionMarche {
    let p: Double
    let cote: Double
    var esperance: Double { p * cote }
}

/// Répartition d'une double chance entre ses deux jambes (mise fixe).
struct Repartition {
    let jambeA: Marche
    let miseA: Double
    let jambeB: Marche
    let miseB: Double
}

/// Règlement de chaque jambe d'une double chance : gagnée, et gagnée par la règle des 2 buts.
struct ReglementJambes {
    let jambeA: Marche
    let gagneeA: Bool
    let avanceA: Bool
    let jambeB: Marche
    let gagneeB: Bool
    let avanceB: Bool
}

/// Pari réglé (match joué) ou en attente (`resultat == nil`).
struct Pari: Identifiable {
    let journee: Int
    let domicile: String
    let exterieur: String
    let marche: Marche
    let p: Double
    let cote: Double
    let esperance: Double
    let manuel: Bool
    let mises: ParMethode
    let misesPourcent: ParMethode
    let repartition: Repartition?
    let tousMarches: [Marche: OptionMarche]
    let source: String
    /// Réglé seulement.
    var resultat: Issue?
    var gagne = false
    var gagneParAvance = false
    var gains = ParMethode()
    var jambes: ReglementJambes?

    var id: String { "\(journee)|\(domicile)|\(exterieur)|\(marche.rawValue)" }
    var enAttente: Bool { resultat == nil }
}

struct ResumeJournee: Identifiable {
    let journee: Int
    let paris: [Pari]
    let gains: ParMethode
    let pourcentage: ParMethode
    let bankrollAvant: ParMethode
    let bankrollApres: ParMethode

    var id: Int { journee }
    var gagnes: Int { paris.filter(\.gagne).count }
}

/// Point du graphique des bankrolls : départ, mouvement de trésorerie ou fin de journée.
struct PointBankroll: Identifiable {
    enum Nature { case depart, mouvement(Double), journee }
    let indice: Int
    let journee: Int
    let nature: Nature
    let bankrolls: ParMethode
    var id: Int { indice }
}

struct ResultatParis {
    let paris: [Pari]
    let bankrolls: ParMethode
    let historique: [PointBankroll]
    let gainsPourcent: ParMethode
    let journees: [ResumeJournee]
    let enAttente: [Pari]
}

enum Paris {
    static let bankrollDepartDefaut = 1000.0
    static let plafondKelly = 0.25
    static let coteMinDefaut = 1.0
    static let coteMaxDefaut = 15.0
    static let coteMinDoubleChanceDefaut = 1.5
    static let miseFixeDefaut = 0.05

    static func fractionKelly(_ p: Double, _ cote: Double, plafond: Double = plafondKelly) -> Double {
        let b = cote - 1
        guard b > 0 else { return 0 }
        return max(0, min((b * p - (1 - p)) / b, plafond))
    }

    /// Un pari manuel mise le même montant (mise fixe) sur les 4 colonnes : Kelly
    /// miserait 0 € dès que le modèle ne voit pas d'avantage.
    static func mises(_ bankroll: ParMethode, p: Double, cote: Double, miseFixe: Double, forcee: Bool) -> ParMethode {
        if forcee { return ParMethode(bankroll.fixe * miseFixe) }
        let f = fractionKelly(p, cote)
        var m = ParMethode()
        m.fixe = bankroll.fixe * miseFixe
        m.kelly = bankroll.kelly * f
        m.demiKelly = bankroll.demiKelly * f / 2
        m.quartKelly = bankroll.quartKelly * f / 4
        return m
    }

    static func pourcentages(_ mises: ParMethode, _ bankroll: ParMethode) -> ParMethode {
        var r = ParMethode()
        for k in MethodeMise.allCases { r[k] = bankroll[k] > 0 ? mises[k] / bankroll[k] * 100 : 0 }
        return r
    }

    /// Probabilités retenues pour parier : poids × modèle + (1 − poids) × marché ;
    /// sans probabilité de marché, le modèle seul.
    static func probabilites(modele: [Double], marche: [Double]?, poids w: Double) -> [Double] {
        guard let marche, marche.count == 3, w < 1 else { return modele }
        return (0..<3).map { w * modele[$0] + (1 - w) * marche[$0] }
    }

    static func options(_ p: [Double], _ cotes: [Double]) -> [Marche: OptionMarche] {
        let (o1, oN, o2) = (cotes[0], cotes[1], cotes[2])
        return [
            .un: OptionMarche(p: p[0], cote: o1), .nul: OptionMarche(p: p[1], cote: oN),
            .deux: OptionMarche(p: p[2], cote: o2),
            .unNul: OptionMarche(p: p[0] + p[1], cote: Cotes.combinee(o1, oN)),
            .unDeux: OptionMarche(p: p[0] + p[2], cote: Cotes.combinee(o1, o2)),
            .nulDeux: OptionMarche(p: p[1] + p[2], cote: Cotes.combinee(oN, o2))
        ]
    }

    /// Bookmaker(s) de la meilleure cote utilisée, par marché (« Winamax+Bwin » pour
    /// une double chance dont les jambes viennent de deux livres).
    static func sources(_ m: Match) -> [Marche: String] {
        guard let s = m.sourcesMeilleuresCotes else {
            return m.cotesMoyennes == nil ? [:] : Dictionary(uniqueKeysWithValues: Marche.allCases.map { ($0, "Moy. en ligne") })
        }
        func texte(_ a: Bookmaker, _ b: Bookmaker? = nil) -> String {
            guard let b, b != a else { return a.titre }
            return "\(a.titre)+\(b.titre)"
        }
        return [.un: texte(s[0]), .nul: texte(s[1]), .deux: texte(s[2]),
                .unNul: texte(s[0], s[1]), .unDeux: texte(s[0], s[2]), .nulDeux: texte(s[1], s[2])]
    }

    /// Meilleur marché de `cles` au-delà du seuil. `bornes` (cote médiane) sert
    /// UNIQUEMENT au filtre cote min/max : un seul livre généreux ne doit pas
    /// sortir un pari de la jauge.
    static func meilleur(_ options: [Marche: OptionMarche], _ cles: [Marche], seuil: Double,
                         coteMin: Double, coteMax: Double?, bornes: [Marche: OptionMarche])
        -> (marche: Marche, option: OptionMarche)? {
        var retenu: (Marche, OptionMarche)?
        var meilleure = seuil
        for cle in cles {
            guard let o = options[cle], let b = bornes[cle] else { continue }
            if b.cote < coteMin { continue }
            if let coteMax, b.cote > coteMax { continue }
            if o.esperance > meilleure {
                retenu = (cle, o)
                meilleure = o.esperance
            }
        }
        return retenu
    }

    struct Candidat {
        let marche: Marche
        let option: OptionMarche
        let manuel: Bool
    }

    static func candidats(_ options: [Marche: OptionMarche], bornes: [Marche: OptionMarche], reglages r: Reglages,
                          manuels: Set<Marche>, exclus: Set<Marche>) -> [Candidat] {
        var liste: [Candidat] = []
        if let s = meilleur(options, Marche.simples, seuil: r.seuil, coteMin: r.coteMin, coteMax: r.coteMax, bornes: bornes),
           !exclus.contains(s.marche) {
            liste.append(Candidat(marche: s.marche, option: s.option, manuel: false))
        }
        if let d = meilleur(options, Marche.doublesChances, seuil: r.seuil,
                            coteMin: max(r.coteMinDoubleChance, r.coteMin), coteMax: r.coteMax, bornes: bornes),
           !exclus.contains(d.marche) {
            liste.append(Candidat(marche: d.marche, option: d.option, manuel: false))
        }
        var couverts = Set(liste.map(\.marche))
        for marche in Marche.allCases where manuels.contains(marche) {
            if couverts.contains(marche) || exclus.contains(marche) { continue }
            guard let o = options[marche] else { continue }
            liste.append(Candidat(marche: marche, option: o, manuel: true))
            couverts.insert(marche)
        }
        return liste
    }

    /// Une jambe « 1 » ou « 2 » gagne aussi si l'équipe a mené de 2 buts ; jamais « N ».
    static func reglerJambe(_ jambe: Marche, _ issue: Issue, avanceDomicile: Int, avanceExterieur: Int)
        -> (gagnee: Bool, parAvance: Bool) {
        switch jambe {
        case .un:
            let parResultat = issue == .domicile, parAvance = avanceDomicile >= 2
            return (parResultat || parAvance, parAvance && !parResultat)
        case .deux:
            let parResultat = issue == .exterieur, parAvance = avanceExterieur >= 2
            return (parResultat || parAvance, parAvance && !parResultat)
        default:
            return (issue == .nul, false)
        }
    }

    /// Rejoue toute la saison : mouvements, paris de chaque journée, puis paris en attente.
    static func historique(ligue: Ligue, reglages r: Reglages, mouvements: [Mouvement],
                           manuels: [PariManuel], exclus: [PariExclu], modele: ModeleForces?) -> ResultatParis {
        var bankrolls = ParMethode(r.bankrollDepart)
        var paris: [Pari] = []
        var journees: [ResumeJournee] = []
        var points = [PointBankroll(indice: 0, journee: 0, nature: .depart, bankrolls: bankrolls)]
        var totalDepose = r.bankrollDepart
        var totalRetire = ParMethode()

        var manuelsParMatch: [String: Set<Marche>] = [:]
        for b in manuels { manuelsParMatch[b.cleMatch, default: []].insert(b.market) }
        var exclusParMatch: [String: Set<Marche>] = [:]
        for b in exclus { exclusParMatch[b.cleMatch, default: []].insert(b.market) }

        var jouesParJournee: [Int: [Match]] = [:]
        for m in ligue.matchsJoues { jouesParJournee[m.journee, default: []].append(m) }
        let toutesJournees = Set(jouesParJournee.keys).union(mouvements.map(\.journee)).sorted()

        for j in toutesJournees {
            for e in mouvements where e.journee == j {
                if e.amount >= 0 {
                    totalDepose += e.amount
                    for k in MethodeMise.allCases { bankrolls[k] += e.amount }
                } else {
                    for k in MethodeMise.allCases {
                        let montant = max(e.amount, -bankrolls[k])
                        bankrolls[k] += montant
                        totalRetire[k] += -montant
                    }
                }
                points.append(PointBankroll(indice: points.count, journee: j, nature: .mouvement(e.amount),
                                            bankrolls: bankrolls))
            }

            let avant = bankrolls
            var parisJournee: [Pari] = []
            var gainsJournee = ParMethode()

            for m in jouesParJournee[j] ?? [] {
                guard let cotes = m.meilleuresCotes, let p1 = m.figeP1, let pN = m.figePN, let p2 = m.figeP2,
                      let issue = m.issue else { continue }
                let probas = probabilites(modele: [p1, pN, p2], marche: Cotes.probabilitesMarchePari(m), poids: r.poidsModele)
                let opts = options(probas, cotes)
                let bornes = m.cotesMedianes.map { options(probas, $0) } ?? opts
                let srcs = sources(m)
                let liste = candidats(opts, bornes: bornes, reglages: r,
                                      manuels: manuelsParMatch[m.id] ?? [], exclus: exclusParMatch[m.id] ?? [])
                guard !liste.isEmpty else { continue }

                var avanceDom = 0, avanceExt = 0
                if let md = m.minutesDomicile, !md.isEmpty, let me = m.minutesExterieur, !me.isEmpty,
                   let a = try? MinutesBut.avancesMax(md, me) {
                    avanceDom = a.domicile
                    avanceExt = a.exterieur
                }

                for c in liste {
                    let ms = mises(avant, p: c.option.p, cote: c.option.cote, miseFixe: r.miseFixe, forcee: c.manuel)
                    var pari = Pari(journee: m.journee, domicile: m.domicile, exterieur: m.exterieur, marche: c.marche,
                                    p: c.option.p, cote: c.option.cote, esperance: c.option.esperance, manuel: c.manuel,
                                    mises: ms, misesPourcent: pourcentages(ms, avant),
                                    repartition: nil, tousMarches: opts, source: srcs[c.marche] ?? "")
                    pari.resultat = issue
                    if let (a, b) = c.marche.jambes, let oa = opts[a]?.cote, let ob = opts[b]?.cote {
                        let ra = reglerJambe(a, issue, avanceDomicile: avanceDom, avanceExterieur: avanceExt)
                        let rb = reglerJambe(b, issue, avanceDomicile: avanceDom, avanceExterieur: avanceExt)
                        var gains = ParMethode()
                        for k in MethodeMise.allCases {
                            let (miseA, miseB) = Cotes.repartition(oa, ob, mise: ms[k])
                            gains[k] = (ra.gagnee ? miseA * (oa - 1) : -miseA) + (rb.gagnee ? miseB * (ob - 1) : -miseB)
                        }
                        let (fa, fb) = Cotes.repartition(oa, ob, mise: ms.fixe)
                        pari = Pari(journee: pari.journee, domicile: pari.domicile, exterieur: pari.exterieur,
                                    marche: pari.marche, p: pari.p, cote: pari.cote, esperance: pari.esperance,
                                    manuel: pari.manuel, mises: ms, misesPourcent: pari.misesPourcent,
                                    repartition: Repartition(jambeA: a, miseA: fa, jambeB: b, miseB: fb),
                                    tousMarches: opts, source: pari.source, resultat: issue,
                                    gagne: ra.gagnee || rb.gagnee, gagneParAvance: ra.parAvance || rb.parAvance,
                                    gains: gains,
                                    jambes: ReglementJambes(jambeA: a, gagneeA: ra.gagnee, avanceA: ra.parAvance,
                                                            jambeB: b, gagneeB: rb.gagnee, avanceB: rb.parAvance))
                    } else {
                        let rg = reglerJambe(c.marche, issue, avanceDomicile: avanceDom, avanceExterieur: avanceExt)
                        pari.gagne = rg.gagnee
                        pari.gagneParAvance = rg.parAvance
                        for k in MethodeMise.allCases {
                            pari.gains[k] = rg.gagnee ? ms[k] * (c.option.cote - 1) : -ms[k]
                        }
                    }
                    for k in MethodeMise.allCases { gainsJournee[k] += pari.gains[k] }
                    parisJournee.append(pari)
                }
            }

            guard !parisJournee.isEmpty else { continue }
            for k in MethodeMise.allCases { bankrolls[k] += gainsJournee[k] }
            var pourcentage = ParMethode()
            for k in MethodeMise.allCases {
                pourcentage[k] = avant[k] > 0 ? (bankrolls[k] / avant[k] - 1) * 100 : 0
            }
            paris += parisJournee
            journees.append(ResumeJournee(journee: j, paris: parisJournee, gains: gainsJournee, pourcentage: pourcentage,
                                          bankrollAvant: avant, bankrollApres: bankrolls))
            points.append(PointBankroll(indice: points.count, journee: j, nature: .journee, bankrolls: bankrolls))
        }

        // Gain global : bankroll ÷ (déposé − retiré réellement appliqué) − 1.
        var gainsPourcent = ParMethode()
        for k in MethodeMise.allCases {
            let base = totalDepose - totalRetire[k]
            gainsPourcent[k] = base > 0 ? (bankrolls[k] / base - 1) * 100 : 0
        }

        let attente = enAttente(ligue: ligue, modele: modele, bankrolls: bankrolls, reglages: r,
                                manuels: manuelsParMatch, exclus: exclusParMatch)
        return ResultatParis(paris: paris, bankrolls: bankrolls, historique: points, gainsPourcent: gainsPourcent,
                             journees: journees, enAttente: attente)
    }

    private static func enAttente(ligue: Ligue, modele: ModeleForces?, bankrolls: ParMethode, reglages r: Reglages,
                                  manuels: [String: Set<Marche>], exclus: [String: Set<Marche>]) -> [Pari] {
        guard let modele else { return [] }
        var liste: [Pari] = []
        for m in ligue.matchsAJouer {
            guard let cotes = m.meilleuresCotes else { continue }
            let probas = probabilites(modele: modele.probas(m.domicile, m.exterieur).triplet,
                                      marche: Cotes.probabilitesMarchePari(m), poids: r.poidsModele)
            let opts = options(probas, cotes)
            let bornes = m.cotesMedianes.map { options(probas, $0) } ?? opts
            let srcs = sources(m)
            for c in candidats(opts, bornes: bornes, reglages: r, manuels: manuels[m.id] ?? [], exclus: exclus[m.id] ?? []) {
                let ms = mises(bankrolls, p: c.option.p, cote: c.option.cote, miseFixe: r.miseFixe, forcee: c.manuel)
                var repartition: Repartition?
                if let (a, b) = c.marche.jambes, let oa = opts[a]?.cote, let ob = opts[b]?.cote {
                    let (fa, fb) = Cotes.repartition(oa, ob, mise: ms.fixe)
                    repartition = Repartition(jambeA: a, miseA: fa, jambeB: b, miseB: fb)
                }
                liste.append(Pari(journee: m.journee, domicile: m.domicile, exterieur: m.exterieur, marche: c.marche,
                                  p: c.option.p, cote: c.option.cote, esperance: c.option.esperance, manuel: c.manuel,
                                  mises: ms, misesPourcent: pourcentages(ms, bankrolls), repartition: repartition,
                                  tousMarches: opts, source: srcs[c.marche] ?? ""))
            }
        }
        return liste
    }
}
