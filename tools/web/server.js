/**
 * Domain Name Finder — Web Server
 * node tools/web/server.js → http://localhost:3738
 */

import http from 'http';
import https from 'https';
import net from 'net';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { exec } from 'child_process';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PORT = 3738;
const TIMEOUT = 7000;

// ── .com — RDAP via IANA (most accurate, no rate-limit issues) ───────────────
function checkCom(name) {
  return new Promise((resolve) => {
    const domain = name + '.com';
    // IANA bootstrap first, then verisign RDAP
    const url = `https://rdap.verisign.com/com/v1/domain/${encodeURIComponent(domain)}`;
    const req = https.get(url, { headers: { Accept: 'application/rdap+json' } }, (res) => {
      let body = '';
      res.on('data', c => { body += c; });
      res.on('end', () => {
        if (res.statusCode === 404) return resolve({ tld: '.com', domain, available: true });
        if (res.statusCode === 200) {
          let registrar = null;
          try {
            const p = JSON.parse(body);
            for (const e of p?.entities || []) {
              if (e?.roles?.includes('registrar')) {
                const fn = e?.vcardArray?.[1]?.find(x => x[0] === 'fn');
                if (fn?.[3]) { registrar = fn[3].trim(); break; }
                if (e?.handle) { registrar = e.handle; break; }
              }
            }
          } catch {}
          return resolve({ tld: '.com', domain, available: false, registrar });
        }
        // Fallback to WHOIS on unexpected status
        checkComWhois(name).then(resolve);
      });
    });
    req.setTimeout(TIMEOUT, () => { req.destroy(); checkComWhois(name).then(resolve); });
    req.on('error', () => checkComWhois(name).then(resolve));
  });
}

// WHOIS fallback for .com
function checkComWhois(name) {
  return new Promise((resolve) => {
    const domain = name + '.com';
    const socket = net.createConnection(43, 'whois.verisign-grs.com');
    let data = '';
    const timer = setTimeout(() => {
      socket.destroy();
      resolve({ tld: '.com', domain, available: null, error: 'timeout' });
    }, TIMEOUT);
    socket.on('connect', () => socket.write(domain + '\r\n'));
    socket.on('data', c => { data += c.toString(); });
    socket.on('end', () => {
      clearTimeout(timer);
      const lower = data.toLowerCase();
      const available = ['no match', 'not found', 'no entries found'].some(s => lower.includes(s));
      const reg = data.match(/Registrar:\s*(.+)/i)?.[1]?.trim() || null;
      resolve({ tld: '.com', domain, available, registrar: reg });
    });
    socket.on('error', (err) => {
      clearTimeout(timer);
      resolve({ tld: '.com', domain, available: null, error: err.message });
    });
  });
}

// ── .io — RDAP via nic.io ────────────────────────────────────────────────────
function checkIo(name) {
  return new Promise((resolve) => {
    const domain = name + '.io';
    const url = `https://rdap.nic.io/domain/${encodeURIComponent(domain)}`;
    const req = https.get(url, { headers: { Accept: 'application/rdap+json' } }, (res) => {
      let body = '';
      res.on('data', c => { body += c; });
      res.on('end', () => {
        if (res.statusCode === 404) return resolve({ tld: '.io', domain, available: true });
        if (res.statusCode === 200) {
          let registrar = null;
          try {
            const p = JSON.parse(body);
            for (const e of p?.entities || []) {
              if (e?.roles?.includes('registrar')) {
                const fn = e?.vcardArray?.[1]?.find(x => x[0] === 'fn');
                if (fn?.[3]) { registrar = fn[3].trim(); break; }
              }
            }
          } catch {}
          return resolve({ tld: '.io', domain, available: false, registrar });
        }
        resolve({ tld: '.io', domain, available: null, error: `HTTP ${res.statusCode}` });
      });
    });
    req.setTimeout(TIMEOUT, () => { req.destroy(); resolve({ tld: '.io', domain, available: null, error: 'timeout' }); });
    req.on('error', (err) => resolve({ tld: '.io', domain, available: null, error: err.message }));
  });
}

// ── Pronounceability filter ──────────────────────────────────────────────────
function isPronounceble(w) {
  if (w.length < 3 || w.length > 14) return false;
  if (!/[aeiou]/i.test(w)) return false;          // needs at least one vowel
  if (/[^a-z]/i.test(w)) return false;
  if (/[^aeiou]{4,}/i.test(w)) return false;      // no 4+ consonants in a row
  if (/[^aeiou]{3}$/i.test(w)) return false;      // no 3+ consonants at end
  if (/^[^aeiou]{3}/i.test(w)) return false;      // no 3+ consonants at start
  return true;
}

// ── Name generator ───────────────────────────────────────────────────────────
function generateVariants(word) {
  const w = word.toLowerCase().trim();
  const raw = new Set([w]);

  // 1. Drop trailing silent 'e'  (trace→trac, pulse→puls, sense→sens)
  if (/[^aeiou]e$/.test(w)) raw.add(w.slice(0, -1));

  // 2. Waze-style final letter swaps
  if (/[aeiou]s$/.test(w)) raw.add(w.replace(/s$/, 'z'));    // ways→waze-like
  if (/[^aeiou]s$/.test(w)) raw.add(w.replace(/s$/, 'z'));   // lens→lenz

  // 3. Lyft-style vowel swap (only when single vowel group = 1 syllable)
  const vowelGroups = w.match(/[aeiou]+/g) || [];
  if (vowelGroups.length === 1) {
    if (/i/.test(w)) raw.add(w.replace(/i/, 'y'));   // drift→dryft
    if (/e/.test(w)) raw.add(w.replace(/e/, 'a'));   // sense→sanse
    if (/o/.test(w)) raw.add(w.replace(/o/, 'u'));   // globe→glube
  }

  // 4. Drop final consonant doubling (keep only if it ends in soft sound)
  if (w.length <= 5 && /[rn]$/.test(w)) raw.add(w + w[w.length - 1]);  // sen→senn, blur→blurr (rare)

  // 5. Natural Latin/romantic suffixes — applied to stem (no trailing vowel)
  const stem = w.replace(/[aeiou]+$/, '');
  for (const s of ['io', 'era', 'ova', 'ara', 'ify', 'ly', 'eo']) {
    raw.add(stem + s);
  }

  // 6. Fused prefix compounds — only if they form a clean-sounding word
  for (const p of ['eco', 'geo', 'air', 'arc', 'lux', 'orb', 'neo', 'aer']) {
    const fused = p + w;
    raw.add(fused);
    // also fused with stem (ecopuls, geopuls)
    if (stem !== w) raw.add(p + stem);
  }

  // 7. -hq only (short, brandable)
  raw.add(w + 'hq');

  return [...raw]
    .filter(isPronounceble)
    .sort((a, b) => a.length - b.length);
}

// ── HTTP server ───────────────────────────────────────────────────────────────
const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);

  if (url.pathname === '/' || url.pathname === '/index.html') {
    const html = fs.readFileSync(path.join(__dirname, 'public', 'index.html'));
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    return res.end(html);
  }

  if (url.pathname === '/generate') {
    const word = url.searchParams.get('word') || '';
    if (!word) { res.writeHead(400); return res.end('{"error":"word required"}'); }
    const variants = generateVariants(word);
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ variants }));
  }

  // SSE: check .com AND .io in parallel per name
  if (url.pathname === '/check-stream') {
    const wordsParam = url.searchParams.get('words') || '';
    const words = wordsParam.split(',').map(w => w.trim()).filter(Boolean);

    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    });

    for (const name of words) {
      const [com, io] = await Promise.all([checkCom(name), checkIo(name)]);
      res.write(`data: ${JSON.stringify({ name, com, io })}\n\n`);
      await new Promise(r => setTimeout(r, 350));  // be nice to RDAP servers
    }

    res.write('data: {"done":true}\n\n');
    return res.end();
  }

  res.writeHead(404);
  res.end('Not found');
});

server.listen(PORT, () => {
  console.log(`\n  Domain Finder → http://localhost:${PORT}\n`);
  exec(`start http://localhost:${PORT}`).unref();
});
