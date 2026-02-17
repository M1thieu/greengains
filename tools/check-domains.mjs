#!/usr/bin/env node

/**
 * Domain Name Availability Checker
 *
 * Usage:
 *   node check-domains.mjs                  # Check built-in name candidates
 *   node check-domains.mjs name1 name2 ...  # Check specific names
 *   node check-domains.mjs --file names.txt # Check names from file (one per line)
 *   node check-domains.mjs --gen            # Generate + check random 1-syllable candidates
 *   node check-domains.mjs --gen 50         # Generate + check 50 random candidates
 */

import net from 'net';
import https from 'https';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const DELAY_MS = 1200;
const TLD = process.env.TLD || '.io';

const WHOIS_SERVERS = {
  '.com': 'whois.verisign-grs.com',
  '.io': 'whois.nic.io',
  '.co': 'whois.nic.co',
};

const RDAP_ENDPOINTS = {
  '.app': 'https://pubapi.registry.google/rdap/domain/',
  '.dev': 'https://pubapi.registry.google/rdap/domain/',
};

const RDAP_BASE = RDAP_ENDPOINTS[TLD];
const WHOIS_SERVER = WHOIS_SERVERS[TLD] || null;
const WHOIS_PORT = 43;
const TIMEOUT = 8000;

const CURATED_NAMES = [
  'lux', 'sol', 'flux', 'vox', 'zen',
  'arc', 'orb', 'crux', 'glow', 'dew',
  'bloom', 'spore', 'fern', 'moss', 'root',
  'grove', 'reef', 'peak', 'drift', 'haze',
  'pulse', 'node', 'mesh', 'grid', 'byte',
  'volt', 'beam', 'core', 'nest', 'link',
  'ping', 'sync', 'scan', 'trace', 'scope',
  'gist', 'verve', 'vim', 'pith', 'glyph',
  'nexus', 'prism', 'shift', 'spark', 'forge',
  'craft', 'helm', 'base', 'sage', 'brine',
  'surge', 'stride', 'leap', 'swift', 'rise',
  'thrive', 'sprint', 'thrust', 'climb', 'sprout',
  'sense', 'sight', 'touch', 'feel', 'glimpse',
  'airnode', 'sunpulse', 'greenbit', 'ecobit',
  'leafnode', 'terravox', 'bioflux', 'earthpulse',
  'quill', 'rune', 'clade', 'vane', 'shard',
  'glint', 'brisk', 'plume', 'sprig', 'thorn',
  'flint', 'slate', 'crest', 'vale',
];

function generateNames() {
  const prefixes = [
    's', 'fl', 'gr', 'br', 'cr', 'tr', 'pr', 'bl', 'cl', 'dr',
    'sp', 'st', 'sw', 'sh', 'th', 'gl', 'pl', 'fr', 'wr', 'sc',
    'sk', 'sn', 'sl', 'sm', 'qu', 'v', 'z', 'n', 'l', 'r',
    'm', 'w', 'k', 'j', 'h', 'f', 'b', 'd', 'g', 'p', 't',
  ];
  const cores = ['a', 'e', 'i', 'o', 'u', 'ai', 'ea', 'ee', 'oo', 'ou', 'oi', 'au', 'ie', 'ei'];
  const suffixes = [
    'x', 'n', 'l', 'r', 'm', 'th', 'se', 'ze', 'ke', 'ge',
    'de', 'te', 'pe', 'be', 'ft', 'nt', 'nd', 'nk', 'ng',
    'rk', 'rn', 'rd', 'rt', 'st', 'sk', 'sp', 'lt', 'lk',
    'lm', 'lp', 'mp', 'nch', 'rch', 'dge', 'tch',
  ];

  const generated = new Set();
  for (const p of prefixes) {
    for (const c of cores) {
      for (const s of suffixes) {
        const name = p + c + s;
        if (name.length >= 3 && name.length <= 6) {
          generated.add(name);
        }
      }
    }
  }
  return [...generated];
}

function whoisLookup(domain) {
  return new Promise((resolve, reject) => {
    if (!WHOIS_SERVER) {
      reject(new Error(`No WHOIS server configured for ${TLD}`));
      return;
    }

    const socket = new net.Socket();
    let data = '';

    socket.setTimeout(TIMEOUT);
    socket.connect(WHOIS_PORT, WHOIS_SERVER, () => {
      socket.write(domain + '\r\n');
    });

    socket.on('data', (chunk) => {
      data += chunk.toString();
    });

    socket.on('end', () => {
      resolve(data);
    });

    socket.on('timeout', () => {
      socket.destroy();
      reject(new Error('WHOIS timeout'));
    });

    socket.on('error', (err) => {
      reject(err);
    });
  });
}

function rdapLookup(domain) {
  return new Promise((resolve, reject) => {
    if (!RDAP_BASE) {
      reject(new Error(`No RDAP endpoint configured for ${TLD}`));
      return;
    }

    const url = `${RDAP_BASE}${encodeURIComponent(domain)}`;
    const request = https.get(url, { headers: { Accept: 'application/rdap+json' } }, (response) => {
      let body = '';

      response.on('data', (chunk) => {
        body += chunk.toString();
      });

      response.on('end', () => {
        resolve({
          statusCode: response.statusCode || 0,
          body,
        });
      });
    });

    request.setTimeout(TIMEOUT, () => {
      request.destroy(new Error('RDAP timeout'));
    });

    request.on('error', (err) => {
      reject(err);
    });
  });
}

function isAvailableFromWhois(raw) {
  const lowerRaw = raw.toLowerCase();
  const availableIndicators = [
    'no match for',
    'domain not found',
    'not found',
    'no object found',
    'no entries found',
    'no data found',
    'status: free',
    'available for registration',
  ];
  return availableIndicators.some((pattern) => lowerRaw.includes(pattern));
}

function extractRegistrarFromWhois(raw) {
  const registrarMatch = raw.match(/(?:Registrar|Sponsoring Registrar):\s*(.+)/i);
  return registrarMatch ? registrarMatch[1].trim() : 'unknown';
}

function extractExpiryFromWhois(raw) {
  const expiryMatch = raw.match(/Registry Expiry Date:\s*(.+)/i);
  return expiryMatch ? expiryMatch[1].trim() : null;
}

function extractRegistrarFromRdap(rawResponse) {
  try {
    const parsed = JSON.parse(rawResponse);
    if (!Array.isArray(parsed?.entities)) {
      return null;
    }

    for (const entity of parsed.entities) {
      if (!Array.isArray(entity?.roles) || !entity.roles.includes('registrar')) {
        continue;
      }

      const vcard = entity?.vcardArray?.[1];
      if (Array.isArray(vcard)) {
        const fnEntry = vcard.find((item) => Array.isArray(item) && item[0] === 'fn');
        if (Array.isArray(fnEntry) && typeof fnEntry[3] === 'string') {
          return fnEntry[3].trim();
        }
      }

      if (typeof entity?.handle === 'string' && entity.handle.trim()) {
        return entity.handle.trim();
      }
    }
  } catch {
    return null;
  }

  return null;
}

async function checkDomain(name) {
  const domain = name + TLD;

  try {
    if (RDAP_BASE) {
      const rdap = await rdapLookup(domain);

      if (rdap.statusCode === 404) {
        return { name, domain, available: true };
      }

      if (rdap.statusCode === 200) {
        return {
          name,
          domain,
          available: false,
          registrar: extractRegistrarFromRdap(rdap.body) || 'unknown',
          expiry: null,
        };
      }

      return {
        name,
        domain,
        available: 'error',
        error: (`RDAP status ${rdap.statusCode}`).slice(0, 80),
      };
    }

    const raw = await whoisLookup(domain);
    if (isAvailableFromWhois(raw)) {
      return { name, domain, available: true };
    }

    return {
      name,
      domain,
      available: false,
      registrar: extractRegistrarFromWhois(raw),
      expiry: extractExpiryFromWhois(raw),
    };
  } catch (err) {
    return { name, domain, available: 'error', error: (err.message || '').slice(0, 80) };
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function main() {
  const args = process.argv.slice(2);
  let names = [];

  if (args.includes('--gen')) {
    const genIdx = args.indexOf('--gen');
    const count = parseInt(args[genIdx + 1], 10) || 100;
    console.log('Generating 1-syllable name candidates...');
    const generated = generateNames();
    console.log(`Generated ${generated.length} total. Sampling ${count} random for checking...`);
    const shuffled = generated.sort(() => Math.random() - 0.5);
    names = shuffled.slice(0, count);
  } else if (args.includes('--file')) {
    const fileIdx = args.indexOf('--file');
    const filePath = args[fileIdx + 1];
    if (!filePath) {
      console.error('Usage: node check-domains.mjs --file <path>');
      process.exit(1);
    }
    const content = fs.readFileSync(path.resolve(filePath), 'utf-8');
    names = content
      .split('\n')
      .map((n) => n.trim().toLowerCase())
      .filter((n) => n && !n.startsWith('#'));
  } else if (args.length > 0) {
    names = args.map((n) => n.trim().toLowerCase());
  } else {
    names = [...CURATED_NAMES];
  }

  names = [...new Set(names)];

  console.log('\n  Domain Availability Checker');
  console.log(`  Checking ${names.length} names for ${TLD} availability`);
  if (RDAP_BASE) {
    console.log(`  RDAP endpoint: ${RDAP_BASE}`);
  } else {
    console.log(`  WHOIS server: ${WHOIS_SERVER || 'N/A'}`);
  }
  console.log(`  Delay: ${DELAY_MS}ms between lookups\n`);
  console.log('-'.repeat(60));

  const available = [];
  const taken = [];
  const errors = [];

  for (let i = 0; i < names.length; i++) {
    const name = names[i];
    const progress = `[${String(i + 1).padStart(3)}/${names.length}]`;
    const result = await checkDomain(name);

    if (result.available === true) {
      console.log(`  ${progress}  AVAILABLE  ${result.domain}`);
      available.push(result);
    } else if (result.available === 'error') {
      console.log(`  ${progress}  ERROR      ${result.domain}  (${result.error})`);
      errors.push(result);
    } else {
      console.log(`  ${progress}  taken      ${result.domain}  (${result.registrar})`);
      taken.push(result);
    }

    if (i < names.length - 1) {
      await sleep(DELAY_MS);
    }
  }

  console.log('\n' + '='.repeat(60));
  console.log('\n  RESULTS SUMMARY\n');

  if (available.length > 0) {
    console.log(`  AVAILABLE DOMAINS (${available.length}):`);
    available.forEach((r) => console.log(`    -> ${r.domain}`));
  } else {
    console.log('  No available domains found in this batch.');
  }

  if (errors.length > 0) {
    console.log(`\n  ERRORS (${errors.length}) - may need re-checking:`);
    errors.forEach((r) => console.log(`    ?  ${r.domain}  (${r.error})`));
  }

  console.log(`\n  Taken: ${taken.length} | Available: ${available.length} | Errors: ${errors.length}`);
  console.log(`  Total checked: ${names.length}`);

  const resultsPath = path.join(__dirname, 'results.json');
  const results = {
    available: available.map((r) => r.domain),
    taken: taken.map((r) => ({ domain: r.domain, registrar: r.registrar })),
    errors: errors.map((r) => ({ domain: r.domain, error: r.error })),
    checkedAt: new Date().toISOString(),
    totalChecked: names.length,
    tld: TLD,
  };
  fs.writeFileSync(resultsPath, JSON.stringify(results, null, 2));
  console.log(`\n  Full results saved to: ${resultsPath}\n`);
}

main().catch(console.error);
