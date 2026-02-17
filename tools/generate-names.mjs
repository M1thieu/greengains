#!/usr/bin/env node

/**
 * Brand Name Generator - Based on the CVCVCV/CVCCV methodology
 *
 * Generates pronounceable FR/EN names with controlled asymmetry
 * Outputs to names-generated.txt for use with check-domains.mjs
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// ── Syllable Bank (FR/EN friendly) ──────────────────────────────────────
const SYLLABLES = [
  // ka-series
  'ka', 'ko', 'ku', 'ke', 'ki',
  // la-series
  'la', 'lo', 'lu', 'le', 'li',
  // na-series
  'na', 'no', 'nu', 'ne', 'ni',
  // sa-series
  'sa', 'so', 'su', 'se', 'si',
  // va-series
  'va', 've', 'vi', 'vo', 'vu',
  // za-series
  'za', 'ze', 'zi', 'zo', 'zu',
  // ra-series
  'ra', 're', 'ri', 'ro', 'ru',
  // ma-series
  'ma', 'me', 'mi', 'mo', 'mu',
  // ta-series
  'ta', 'te', 'ti', 'to', 'tu',
  // pa-series
  'pa', 'pe', 'pi', 'po', 'pu',
  // ba-series
  'ba', 'be', 'bi', 'bo', 'bu',
  // da-series
  'da', 'de', 'di', 'do', 'du',
  // fa-series
  'fa', 'fe', 'fi', 'fo', 'fu',
  // ga-series (soft)
  'ga', 'go', 'gu',
];

// Soft clusters that work in both FR/EN
const SOFT_CLUSTERS = ['vr', 'ry', 'ny', 'lv', 'rv', 'ly', 'vy', 'zy'];

// Asymmetry injections (use sparingly - 1 per name max)
const ASYMMETRY = {
  // Replace vowel with y
  vowelToY: (name) => {
    const vowels = ['a', 'e', 'i', 'o', 'u'];
    const positions = [];
    for (let i = 1; i < name.length - 1; i++) {
      if (vowels.includes(name[i])) positions.push(i);
    }
    if (positions.length === 0) return null;
    const pos = positions[Math.floor(Math.random() * positions.length)];
    return name.slice(0, pos) + 'y' + name.slice(pos + 1);
  },

  // Replace s with z
  sToZ: (name) => {
    if (!name.includes('s')) return null;
    return name.replace('s', 'z');
  },

  // Add x before last consonant
  addX: (name) => {
    const consonants = 'bcdfgklmnprstvz';
    for (let i = name.length - 1; i >= 0; i--) {
      if (consonants.includes(name[i])) {
        return name.slice(0, i) + 'x' + name.slice(i);
      }
    }
    return null;
  },

  // End with -yx
  endYx: (name) => {
    if (name.length < 4) return null;
    const vowels = 'aeiou';
    if (vowels.includes(name[name.length - 1])) {
      return name.slice(0, -1) + 'yx';
    }
    return name + 'yx';
  },

  // End with -xa
  endXa: (name) => {
    if (name.length < 4) return null;
    const vowels = 'aeiou';
    if (vowels.includes(name[name.length - 1])) {
      return name.slice(0, -1) + 'xa';
    }
    return name + 'xa';
  },
};

// ── Generation Functions ────────────────────────────────────────────────

function pickRandom(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

// Generate CVCVCV pattern (3 syllables)
function generateCVCVCV() {
  const s1 = pickRandom(SYLLABLES);
  const s2 = pickRandom(SYLLABLES);
  const s3 = pickRandom(SYLLABLES);
  return s1 + s2 + s3;
}

// Generate CVCCV pattern (2 syllables with soft cluster)
function generateCVCCV() {
  const s1 = pickRandom(SYLLABLES);
  const cluster = pickRandom(SOFT_CLUSTERS);
  const vowel = pickRandom(['a', 'e', 'i', 'o', 'u']);
  return s1 + cluster + vowel;
}

// Generate 2-syllable (shorter, 4-5 chars)
function generate2Syllable() {
  const s1 = pickRandom(SYLLABLES);
  const s2 = pickRandom(SYLLABLES);
  return s1 + s2;
}

// Apply one asymmetry randomly
function applyAsymmetry(name) {
  const methods = Object.values(ASYMMETRY);
  const method = pickRandom(methods);
  return method(name);
}

// ── Main Generator ──────────────────────────────────────────────────────

function generateNames(count = 500) {
  const names = new Set();
  const patterns = [generateCVCVCV, generateCVCCV, generate2Syllable];

  while (names.size < count) {
    // Pick a pattern
    const pattern = pickRandom(patterns);
    let name = pattern();

    // 50% chance to apply asymmetry
    if (Math.random() > 0.5) {
      const asymName = applyAsymmetry(name);
      if (asymName && asymName.length >= 4 && asymName.length <= 7) {
        name = asymName;
      }
    }

    // Filter: 4-7 chars, no double letters, pronounceable
    if (name.length >= 4 && name.length <= 7) {
      // No triple letters
      if (!/(.)\1\1/.test(name)) {
        // No awkward combos
        if (!/[xzq]{2}/.test(name) && !/[bcdfgklmnprstvz]{3}/.test(name)) {
          names.add(name);
        }
      }
    }
  }

  return [...names];
}

// ── Curated High-Quality Seeds ──────────────────────────────────────────
// These follow the methodology precisely
const CURATED_SEEDS = [
  // CVCVCV with y-asymmetry
  'kovyra', 'sovyra', 'novyra', 'lovyra', 'rovyra',
  'koryva', 'soryva', 'noryva', 'loryva', 'toryva',
  'kovira', 'sovira', 'novira', 'lovira', 'rovira',
  'koryna', 'soryna', 'noryna', 'loryna', 'toryna',
  'kavyro', 'savyro', 'navyro', 'lavyro', 'ravyro',

  // CVCVCV with z-asymmetry
  'kozira', 'sozira', 'nozira', 'lozira', 'rozira',
  'kavizo', 'savizo', 'navizo', 'lavizo', 'ravizo',
  'zorila', 'zorima', 'zorina', 'zorisa', 'zorita',

  // CVCCV soft clusters
  'kovra', 'sovra', 'novra', 'lovra', 'rovra',
  'kalvy', 'salvy', 'nalvy', 'lalvy', 'ralvy',
  'karvy', 'sarvy', 'narvy', 'larvy', 'tarvy',

  // Ending variations
  'noryx', 'soryx', 'koryx', 'loryx', 'toryx',
  'novixa', 'sovixa', 'kovixa', 'lovixa', 'tovixa',
  'luvixa', 'ruvixa', 'suvixa', 'nuvixa', 'kuvixa',

  // 2-syllable tight
  'kova', 'sova', 'nova', 'lova', 'rova',
  'kovi', 'sovi', 'novi', 'lovi', 'rovi',
  'vora', 'vori', 'voru', 'voro', 'vore',
  'zori', 'zora', 'zoru', 'zoro', 'zore',
  'nyva', 'nyvo', 'nyvi', 'nyvra', 'nyvro',

  // More natural-sounding
  'kavora', 'savora', 'navora', 'lavora', 'ravora',
  'kivora', 'sivora', 'nivora', 'livora', 'rivora',
  'koreva', 'soreva', 'noreva', 'loreva', 'toreva',
  'valira', 'valiro', 'valira', 'valori', 'valoru',
  'venira', 'veniro', 'venira', 'venori', 'venoru',

  // Waze-like flow
  'senly', 'renly', 'kenly', 'venly', 'nenly',
  'senya', 'renya', 'kenya', 'venya', 'nenya',
  'sivyo', 'rivyo', 'kivyo', 'vivyo', 'nivyo',
  'sovya', 'rovya', 'kovya', 'lovya', 'novya',
];

// ── Output ──────────────────────────────────────────────────────────────

const args = process.argv.slice(2);
const count = parseInt(args[0]) || 300;

console.log(`\n  Brand Name Generator`);
console.log(`  Methodology: CVCVCV/CVCCV + controlled asymmetry`);
console.log(`  Target: 5-7 chars, FR/EN pronounceable\n`);

// Combine curated + generated
const generated = generateNames(count);
const allNames = [...new Set([...CURATED_SEEDS, ...generated])];

console.log(`  Generated: ${generated.length} random names`);
console.log(`  Curated seeds: ${CURATED_SEEDS.length}`);
console.log(`  Total unique: ${allNames.length}\n`);

// Save to file
const outputPath = path.join(__dirname, 'names-generated.txt');
const content = `# Auto-generated brand name candidates
# Run: node check-domains.mjs --file names-generated.txt
# Generated: ${new Date().toISOString()}
# Methodology: CVCVCV/CVCCV + 1 asymmetry max

${allNames.join('\n')}
`;

fs.writeFileSync(outputPath, content);
console.log(`  Saved to: ${outputPath}`);
console.log(`\n  Next step:`);
console.log(`  node check-domains.mjs --file names-generated.txt\n`);
