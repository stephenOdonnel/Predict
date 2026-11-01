//
//  PasswordManager.swift
//  Predict
//  © 2026 Stephen O'Donnell, Tanguy Labbe · GNU GPL v3 ou ultérieure (fichier LICENSE).
//
//  Pas de mot de passe : l'application s'ouvre directement. Ce fichier garde la
//  clé des sceaux d'intégrité et la clé The Odds API (StockageAuth), et les
//  sceaux eux-mêmes (IntegriteStockage).
//
import Foundation
import Security
import CryptoKit

// MARK: - Stockage local des clés

/// Le trousseau n'est pas utilisé : une application signée en ad-hoc ne peut
/// pas être inscrite durablement dans la liste des applications autorisées
/// d'un élément du trousseau, et macOS redemanderait l'autorisation à chaque
/// lancement.
///
/// ⚠️ Ce fichier est moins protégé que le trousseau : il n'est pas chiffré au repos
/// et tout programme lancé sous ce compte peut le lire.
enum StockageAuth {

    /// Fichier dédié, hors du domaine de préférences : `defaults delete com.predict.app`
    /// ne doit pas effacer la clé des sceaux.
    private static let dossier: URL? = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
        .appendingPathComponent("Predict", isDirectory: true)

    private static var fichier: URL? { dossier?.appendingPathComponent("auth.json") }

    private static var cache: [String: Data]?

    private static func charger() -> [String: Data] {
        if let cache { return cache }

        var contenu: [String: Data] = [:]
        if let fichier, let brut = try? Data(contentsOf: fichier),
           let decode = try? JSONDecoder().decode([String: Data].self, from: brut) {
            contenu = decode
        }

        cache = contenu
        return contenu
    }

    private static func enregistrer(_ contenu: [String: Data]) {
        cache = contenu
        guard let dossier, let fichier,
              let brut = try? JSONEncoder().encode(contenu) else { return }

        try? FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        try? brut.write(to: fichier, options: .atomic)
        // Lecture/écriture réservées à l'utilisateur
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dossier.path)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fichier.path)
    }

    private static func cle(_ service: String, _ account: String?) -> String {
        account.map { "\(service).\($0)" } ?? service
    }

    static func read(service: String, account: String?) -> (data: Data?, status: OSStatus) {
        let donnees = charger()[cle(service, account)]
        return (donnees, donnees == nil ? errSecItemNotFound : errSecSuccess)
    }

    @discardableResult
    static func write(_ data: Data, service: String, account: String?, label: String? = nil) -> OSStatus {
        var contenu = charger()
        contenu[cle(service, account)] = data
        enregistrer(contenu)
        return errSecSuccess
    }

    static func delete(service: String, account: String?) {
        var contenu = charger()
        contenu.removeValue(forKey: cle(service, account))
        enregistrer(contenu)
    }

    // MARK: Compteurs de tentatives (même fichier : un effacement des préférences
    // ne doit pas suffire à remettre le blocage à zéro).

    static func nombre(_ cle: String) -> Double {
        guard let d = charger()[cle], let t = String(data: d, encoding: .utf8) else { return 0 }
        return Double(t) ?? 0
    }

    static func definirNombre(_ valeur: Double, _ cle: String) {
        var contenu = charger()
        contenu[cle] = Data(String(valeur).utf8)
        enregistrer(contenu)
    }

    static func supprimerNombre(_ cle: String) {
        var contenu = charger()
        contenu.removeValue(forKey: cle)
        enregistrer(contenu)
    }
}

// MARK: - Intégrité des fichiers de données

/// Chaque JSON écrit par l'application est accompagné d'un sceau
/// `<fichier>.hmac` (HMAC-SHA256). Au chargement, le sceau est recalculé : un
/// fichier modifié ailleurs que dans l'application est refusé, et la sauvegarde
/// reste bloquée tant que l'incohérence n'est pas levée — les données déjà
/// enregistrées ne peuvent donc pas être écrasées par un contenu partiel.
///
/// ⚠️ Portée : la clé vit dans `auth.json` (0600), puisque le trousseau a été
/// écarté. Cela détecte toute édition du JSON
/// — à la main ou par un script — mais pas un
/// attaquant qui lirait aussi `auth.json` pour recalculer le sceau.
enum IntegriteStockage {

    private static let service = "com.predict.app.integrite"
    private static let compteCle = "hmac-key-v1"
    private static let prefixeAdoption = "hmac-adopte"

    /// Adoption **par fichier** : dès qu'un fichier donné a été scellé une fois,
    /// l'absence de son `.hmac` devient une anomalie — sans quoi il suffirait de
    /// supprimer le sceau pour contourner le contrôle. Un drapeau global serait
    /// faux : sceller `league_data.json` ferait aussitôt rejeter `app_state.json`,
    /// qui n'a pas encore été lu.
    static func estActive(_ nom: String) -> Bool {
        StockageAuth.read(service: service, account: "\(prefixeAdoption).\(nom)").data != nil
    }

    private static func activer(_ nom: String) {
        guard !estActive(nom) else { return }
        StockageAuth.write(Data([1]), service: service, account: "\(prefixeAdoption).\(nom)",
                           label: "Predict – contrôle d'intégrité")
    }

    private static func cle() -> SymmetricKey {
        if let brut = StockageAuth.read(service: service, account: compteCle).data, brut.count == 32 {
            return SymmetricKey(data: brut)
        }
        let nouvelle = SymmetricKey(size: .bits256)
        StockageAuth.write(nouvelle.withUnsafeBytes { Data($0) },
                           service: service, account: compteCle,
                           label: "Predict – clé d'intégrité")
        return nouvelle
    }

    /// Le nom du fichier entre dans le calcul : un JSON ne peut donc pas être
    /// recopié sous un autre nom en gardant son sceau.
    private static func message(_ donnees: Data, nom: String) -> Data {
        var m = Data(nom.utf8)
        m.append(0)
        m.append(donnees)
        return m
    }

    /// Contenu du fichier `<nom>.hmac`.
    ///
    /// `contenu` est la copie du dernier état scellé. Elle sert à montrer
    /// précisément ce qui a changé, et à revenir en arrière : sans elle, une
    /// altération détectée au démarrage ne pourrait être comparée à rien.
    /// Elle n'affaiblit pas le contrôle — c'est le texte même qu'authentifie
    /// `hmac`, donc sa propre authenticité se vérifie avec le même sceau.
    private struct Sceau: Codable {
        let hmac: String
        let contenu: String
    }

    static func sceau(_ donnees: Data, nom: String) -> Data {
        activer(nom)
        let code = HMAC<SHA256>.authenticationCode(for: message(donnees, nom: nom), using: cle())
        let enveloppe = Sceau(hmac: Data(code).base64EncodedString(),
                              contenu: donnees.base64EncodedString())
        return (try? JSONEncoder().encode(enveloppe))
            ?? Data(Data(code).base64EncodedString().utf8)
    }

    private static func codeAttendu(_ sceau: Data) -> Data? {
        if let enveloppe = try? JSONDecoder().decode(Sceau.self, from: sceau) {
            return Data(base64Encoded: enveloppe.hmac)
        }
        guard let texte = String(data: sceau, encoding: .utf8) else { return nil }
        return Data(base64Encoded: texte.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func verifier(_ donnees: Data, nom: String, sceau: Data) -> Bool {
        guard let code = codeAttendu(sceau) else { return false }
        return HMAC<SHA256>.isValidAuthenticationCode(code,
                                                      authenticating: message(donnees, nom: nom),
                                                      using: cle())
    }

    /// Dernier contenu scellé, et seulement s'il correspond au sceau : une copie
    /// trafiquée ne sert pas de référence.
    static func contenuScelle(_ sceau: Data, nom: String) -> Data? {
        guard let enveloppe = try? JSONDecoder().decode(Sceau.self, from: sceau),
              let donnees = Data(base64Encoded: enveloppe.contenu),
              verifier(donnees, nom: nom, sceau: sceau)
        else { return nil }
        return donnees
    }
}
