//
//  XgEnLigne.swift
//  Predict
//  © 2026 Stephen O'Donnell, Tanguy Labbe · GNU GPL v3 ou ultérieure (fichier LICENSE).
//
//  xG des matchs joués, téléchargés sur Understat (understat.com) : une seule
//  requête GET par mise à jour (le JSON de toute la saison), sans cookie ni
//  clé ; rien d'autre que l'adresse n'est envoyé. football-data.co.uk ne
//  fournit pas de xG.
//
//  Format (endpoint que la page « league » appelle elle-même) :
//    https://understat.com/getLeagueData/Ligue_1/2026
//    { "teams": …, "players": …, "dates": [ { "id": "…", "isResult": true,
//       "h": { "title": "Lille" }, "a": { "title": "Brest" },
//       "goals": { "h": "2", "a": "1" }, "xG": { "h": "1.83", "a": "0.74" },
//       "datetime": "2026-08-22 19:00:00" }, … ] }
//  Understat donne les nombres en chaînes de caractères ; les deux formes sont lues.
//
import Foundation

enum XgEnLigne {
    static var site: URL { URL(string: "https://understat.com/league/\(Championnat.actif.codeUnderstat)")! }

    /// « 2026-27 » → 2026 (année de début, comme dans l'adresse Understat).
    static func annee(saison: String) -> String? {
        let p = saison.split(separator: "-")
        guard p.count == 2, p[0].count == 4, p[0].allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return String(p[0])
    }

    static func requete(saison: String) -> URLRequest? {
        guard let annee = annee(saison: saison),
              let url = URL(string: "https://understat.com/getLeagueData/\(Championnat.actif.codeUnderstat)/\(annee)") else { return nil }
        var r = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        r.httpShouldHandleCookies = false
        r.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        r.setValue("https://understat.com/league/\(Championnat.actif.codeUnderstat)/\(annee)", forHTTPHeaderField: "Referer")
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        return r
    }

    /// Un match joué avec ses xG.
    struct Rencontre: Equatable {
        let domicile: String
        let exterieur: String
        let butsDomicile: Int
        let butsExterieur: Int
        let xgDomicile: Double
        let xgExterieur: Double
        /// AAAA-MM-JJ (début du « datetime » Understat), si présent.
        let date: String?
    }

    /// Nombre donné en chaîne (« 1.83 ») ou en nombre.
    private struct Nombre: Decodable {
        let valeur: Double
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let x = try? c.decode(Double.self) {
                valeur = x
            } else if let s = try? c.decode(String.self), let x = Double(s.trimmingCharacters(in: .whitespaces)) {
                valeur = x
            } else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "nombre attendu")
            }
        }
    }
    private struct Paire: Decodable {
        let h: Nombre?
        let a: Nombre?
    }
    private struct Club: Decodable {
        let title: String
    }
    private struct Evenement: Decodable {
        let termine: Bool
        let domicile: Club
        let exterieur: Club
        let buts: Paire?
        let xg: Paire?
        let date: String?
        enum CodingKeys: String, CodingKey {
            case termine = "isResult", domicile = "h", exterieur = "a", buts = "goals", xg = "xG", date = "datetime"
        }
    }
    /// Un événement illisible est ignoré sans faire échouer toute la saison.
    private struct Tolerant: Decodable {
        let evenement: Evenement?
        init(from decoder: Decoder) throws { evenement = try? Evenement(from: decoder) }
    }
    private struct Reponse: Decodable {
        let dates: [Tolerant]
    }

    /// Réponse Understat → matchs joués aux noms de la saison. `inconnus` : clubs
    /// qu'on ne sait pas rapprocher ; `invalides` : matchs joués sans xG ou aux valeurs absurdes.
    static func lire(_ donnees: Data, equipes: [String])
        throws -> (rencontres: [Rencontre], inconnus: [String], invalides: Int) {
        let reponse = try JSONDecoder().decode(Reponse.self, from: donnees)
        var rencontres: [Rencontre] = []
        var inconnus = Set<String>()
        var invalides = 0
        for e in reponse.dates.compactMap(\.evenement) where e.termine {
            let h = CotesEnLigne.equipe(e.domicile.title, parmi: equipes)
            let a = CotesEnLigne.equipe(e.exterieur.title, parmi: equipes)
            if h == nil { inconnus.insert(e.domicile.title) }
            if a == nil { inconnus.insert(e.exterieur.title) }
            guard let h, let a else { continue }
            guard let bh = e.buts?.h?.valeur, let ba = e.buts?.a?.valeur,
                  let xh = e.xg?.h?.valeur, let xa = e.xg?.a?.valeur,
                  bh == bh.rounded(), ba == ba.rounded(),
                  (0...Double(Limites.buts)).contains(bh), (0...Double(Limites.buts)).contains(ba),
                  xh.isFinite, xa.isFinite, (0...Limites.xg).contains(xh), (0...Limites.xg).contains(xa) else {
                invalides += 1
                continue
            }
            rencontres.append(Rencontre(domicile: h, exterieur: a, butsDomicile: Int(bh), butsExterieur: Int(ba),
                                        xgDomicile: xh, xgExterieur: xa, date: e.date.map { String($0.prefix(10)) }))
        }
        return (rencontres, inconnus.sorted(), invalides)
    }
}
