# Domain Availability Checker

Outil pour vérifier la disponibilité de domaines en masse via WHOIS + RDAP.

## Installation

1. Avoir Node.js installé (version 14+)
2. Copier les fichiers `check-domains.mjs` et `package.json`
3. Aucune installation de dépendances nécessaire (utilise raw TCP sockets)

## Usage

### Vérifier des domaines individuels

```bash
# Par défaut check .io
node check-domains.mjs nom1 nom2 nom3

# Check .com
TLD=.com node check-domains.mjs nom1 nom2 nom3

# Check autres TLDs
TLD=.app node check-domains.mjs nom1 nom2
TLD=.dev node check-domains.mjs nom1 nom2
```

### Vérifier depuis un fichier

```bash
# Créer un fichier avec un nom par ligne
echo "drift" > names.txt
echo "pulse" >> names.txt
echo "sigma" >> names.txt

# Checker le fichier
node check-domains.mjs --file names.txt

# Avec TLD spécifique
TLD=.com node check-domains.mjs --file names.txt
```

### Format du fichier de noms

```txt
# Commentaires avec # sont ignorés
drift
pulse
sigma

# Lignes vides sont ignorées

lambyx
sigmyx
```

## TLDs supportés

- `.io` (défaut) - WHOIS (`whois.nic.io`)
- `.com` - WHOIS (`whois.verisign-grs.com`)
- `.app` - RDAP (`https://pubapi.registry.google/rdap/domain/<domain>`)
- `.dev` - RDAP (`https://pubapi.registry.google/rdap/domain/<domain>`)
- `.co` - config présent, mais selon DNS/réseau le WHOIS peut échouer

## Output

L'outil affiche:
- ✅ AVAILABLE pour les domaines disponibles
- ❌ taken pour les domaines pris (avec le registrar)
- ⚠️ ERROR pour les erreurs (timeout, DNS, etc.)

Les résultats sont sauvegardés dans `results.json`.

## Délai entre requêtes

1200ms (1.2s) entre chaque lookup pour éviter le rate limiting WHOIS.

## Tips

- Pour vérifier rapidement un concept: créer un fichier avec toutes les variantes
- Checker d'abord .io (plus rapide), puis .com si besoin
- Les domaines avec -yx/-ix ont plus de chance d'être dispo
- Les domaines 1-syllabe simples sont quasi tous pris

## Exemples

```bash
# Quick check de 3 noms en .com
TLD=.com node check-domains.mjs lambyx sigmyx thetyx

# Check une grosse liste en .io
node check-domains.mjs --file names-greek-derivatives.txt

# Check les mêmes noms sur plusieurs TLDs
TLD=.com node check-domains.mjs --file mynames.txt
TLD=.io node check-domains.mjs --file mynames.txt
```

## Troubleshooting

**"Cannot use import statement outside a module"**
→ Vérifier que `package.json` contient `"type": "module"`

**"ENOTFOUND whois.nic.co"**
→ Ton DNS ne résout pas ce serveur WHOIS; utilise `.com`/`.io`/`.app`/`.dev`

**Timeout errors**
→ Certains WHOIS servers sont lents, c'est normal pour 1-2 erreurs sur 100 requêtes
