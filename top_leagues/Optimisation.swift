//
//  Optimisation.swift
//  Predict
//  © 2026 Stephen O'Donnell, Tanguy Labbe · GNU GPL v3 ou ultérieure (fichier LICENSE).
//
//  Minimisation sous bornes (L-BFGS projeté), à la place de
//  `scipy.optimize.minimize(method="L-BFGS-B", jac=True)` de l'app Python.
//
import Foundation

enum Optimisation {

    struct Resultat {
        let x: [Double]
        let valeur: Double
        let iterations: Int
        let converge: Bool
    }

    /// L-BFGS avec projection sur la boîte `bornes` : les variables posées sur
    /// une borne vers laquelle pousse le gradient sont figées pour l'itération,
    /// la recherche linéaire (Armijo, retour arrière) suit le chemin projeté.
    /// Arrêt quand le gradient projeté passe sous `toleranceGradient` ou que la
    /// baisse relative de la fonction devient négligeable.
    static func minimiser(
        depart: [Double],
        bornes: [(Double, Double)],
        iterationsMax: Int = 1000,
        memoire: Int = 10,
        toleranceGradient: Double = 1e-8,
        toleranceRelative: Double = 1e-15,
        fonction: ([Double]) -> (valeur: Double, gradient: [Double])
    ) -> Resultat {
        let n = depart.count
        func projeter(_ v: [Double]) -> [Double] {
            var p = v
            for i in 0..<n { p[i] = min(max(p[i], bornes[i].0), bornes[i].1) }
            return p
        }
        func produit(_ a: [Double], _ b: [Double]) -> Double {
            var s = 0.0
            for i in 0..<n { s += a[i] * b[i] }
            return s
        }

        var x = projeter(depart)
        var (fx, g) = fonction(x)
        var historiqueS: [[Double]] = []
        var historiqueY: [[Double]] = []
        var iteration = 0
        var converge = false

        while iteration < iterationsMax {
            iteration += 1

            // Variables actives : sur une borne, gradient dirigé vers l'extérieur.
            var libre = [Bool](repeating: true, count: n)
            var normeProjetee = 0.0
            for i in 0..<n {
                if (x[i] <= bornes[i].0 && g[i] > 0) || (x[i] >= bornes[i].1 && g[i] < 0) {
                    libre[i] = false
                } else {
                    normeProjetee = max(normeProjetee, abs(g[i]))
                }
            }
            if normeProjetee < toleranceGradient {
                converge = true
                break
            }
            func masquer(_ v: [Double]) -> [Double] {
                var m = v
                for i in 0..<n where !libre[i] { m[i] = 0 }
                return m
            }

            // Double boucle L-BFGS restreinte aux variables libres.
            var q = masquer(g)
            var alphas: [Double] = []
            var rhos: [Double] = []
            let sMasques = historiqueS.map(masquer)
            let yMasques = historiqueY.map(masquer)
            for k in stride(from: sMasques.count - 1, through: 0, by: -1) {
                let sy = produit(sMasques[k], yMasques[k])
                let rho = sy > 1e-300 ? 1 / sy : 0
                let a = rho * produit(sMasques[k], q)
                for i in 0..<n { q[i] -= a * yMasques[k][i] }
                alphas.append(a)
                rhos.append(rho)
            }
            if let s = sMasques.last, let y = yMasques.last {
                let yy = produit(y, y)
                let gamma = yy > 0 ? produit(s, y) / yy : 1
                for i in 0..<n { q[i] *= gamma > 0 ? gamma : 1 }
            }
            for (j, k) in (0..<sMasques.count).enumerated() {
                let indice = alphas.count - 1 - j
                let b = rhos[indice] * produit(yMasques[k], q)
                for i in 0..<n { q[i] += sMasques[k][i] * (alphas[indice] - b) }
            }
            var direction = masquer(q.map { -$0 })

            if produit(direction, g) >= 0 {
                // Courbure non exploitable : retour à la plus forte pente.
                historiqueS.removeAll()
                historiqueY.removeAll()
                direction = masquer(g.map { -$0 })
            }

            // Premier pas prudent tant qu'aucune courbure n'est connue.
            var pas = historiqueS.isEmpty ? min(1, 1 / max(normeProjetee, 1e-12)) : 1
            var accepte = false
            var xNouveau = x
            var fNouveau = fx
            var gNouveau = g
            for _ in 0..<60 {
                var essai = x
                for i in 0..<n { essai[i] += pas * direction[i] }
                essai = projeter(essai)
                let (f, gr) = fonction(essai)
                var deplacement = [Double](repeating: 0, count: n)
                for i in 0..<n { deplacement[i] = essai[i] - x[i] }
                if f.isFinite && f <= fx + 1e-4 * produit(g, deplacement) {
                    xNouveau = essai
                    fNouveau = f
                    gNouveau = gr
                    accepte = true
                    break
                }
                pas *= 0.5
            }
            guard accepte else {
                // Plus aucun progrès possible à la précision machine.
                converge = true
                break
            }

            var s = [Double](repeating: 0, count: n)
            var y = [Double](repeating: 0, count: n)
            for i in 0..<n {
                s[i] = xNouveau[i] - x[i]
                y[i] = gNouveau[i] - g[i]
            }
            if produit(s, y) > 1e-12 * max(produit(y, y), 1e-300) {
                historiqueS.append(s)
                historiqueY.append(y)
                if historiqueS.count > memoire {
                    historiqueS.removeFirst()
                    historiqueY.removeFirst()
                }
            }

            let baisse = (fx - fNouveau) / max(abs(fx), abs(fNouveau), 1)
            x = xNouveau
            fx = fNouveau
            g = gNouveau
            if baisse <= toleranceRelative {
                converge = true
                break
            }
        }

        return Resultat(x: x, valeur: fx, iterations: iteration, converge: converge)
    }
}
