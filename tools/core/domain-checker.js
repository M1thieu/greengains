/**
 * Domain availability checker using raw WHOIS TCP connections
 */

import net from 'net';
import https from 'https';
import {
  WHOIS_SERVERS,
  RDAP_ENDPOINTS,
  WHOIS_PORT,
  WHOIS_TIMEOUT,
  LOOKUP_DELAY,
} from './config.js';

/**
 * Check if a domain is available via WHOIS
 * @param {string} domain - Full domain name (e.g., "example.com")
 * @param {string} tld - TLD including dot (e.g., ".com")
 * @returns {Promise<{domain: string, available: boolean, registrar?: string, error?: string}>}
 */
export async function checkDomain(domain, tld = '.io') {
  const rdapBaseUrl = RDAP_ENDPOINTS[tld];
  if (rdapBaseUrl) {
    return checkDomainWithRdap(domain, rdapBaseUrl);
  }

  const whoisServer = WHOIS_SERVERS[tld];

  if (!whoisServer) {
    return {
      domain,
      available: false,
      error: `No WHOIS server configured for ${tld}`,
    };
  }

  return new Promise((resolve) => {
    const socket = net.createConnection(WHOIS_PORT, whoisServer);
    let data = '';

    const timeout = setTimeout(() => {
      socket.destroy();
      resolve({
        domain,
        available: false,
        error: 'WHOIS timeout',
      });
    }, WHOIS_TIMEOUT);

    socket.on('connect', () => {
      socket.write(domain + '\r\n');
    });

    socket.on('data', (chunk) => {
      data += chunk.toString();
    });

    socket.on('end', () => {
      clearTimeout(timeout);

      const lowerData = data.toLowerCase();

      // Check if domain is available
      const availableIndicators = [
        'no match',
        'not found',
        'domain not found',
        'no object found',
        'no entries found',
        'no data found',
        'status: free',
        'available for registration',
      ];

      const isAvailable = availableIndicators.some(indicator =>
        lowerData.includes(indicator)
      );

      // Extract registrar if taken
      let registrar = null;
      if (!isAvailable) {
        const registrarMatch = data.match(/(?:Registrar|Sponsoring Registrar):\s*(.+)/i);
        if (registrarMatch) {
          registrar = registrarMatch[1].trim();
        }
      }

      resolve({
        domain,
        available: isAvailable,
        registrar,
      });
    });

    socket.on('error', (err) => {
      clearTimeout(timeout);
      resolve({
        domain,
        available: false,
        error: err.message,
      });
    });
  });
}

function checkDomainWithRdap(domain, rdapBaseUrl) {
  return new Promise((resolve) => {
    const url = `${rdapBaseUrl}${encodeURIComponent(domain)}`;
    const request = https.get(url, { headers: { Accept: 'application/rdap+json' } }, (response) => {
      let data = '';
      response.on('data', (chunk) => {
        data += chunk.toString();
      });
      response.on('end', () => {
        if (response.statusCode === 404) {
          resolve({ domain, available: true });
          return;
        }

        if (response.statusCode === 200) {
          resolve({
            domain,
            available: false,
            registrar: extractRdapRegistrar(data) || 'unknown',
          });
          return;
        }

        resolve({
          domain,
          available: false,
          error: `RDAP status ${response.statusCode}`,
        });
      });
    });

    request.setTimeout(WHOIS_TIMEOUT, () => {
      request.destroy(new Error('RDAP timeout'));
    });

    request.on('error', (err) => {
      resolve({
        domain,
        available: false,
        error: err.message,
      });
    });
  });
}

function extractRdapRegistrar(rawResponse) {
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

/**
 * Check multiple domains with delay between lookups
 * @param {string[]} names - Array of domain names without TLD
 * @param {string} tld - TLD to check
 * @param {function} onProgress - Callback for progress updates
 * @returns {Promise<Array>}
 */
export async function checkDomains(names, tld = '.io', onProgress = null) {
  const results = [];

  for (let i = 0; i < names.length; i++) {
    const name = names[i].trim().toLowerCase();
    if (!name || name.startsWith('#')) continue;

    const domain = name + tld;
    const result = await checkDomain(domain, tld);
    results.push(result);

    if (onProgress) {
      onProgress({
        current: i + 1,
        total: names.length,
        result,
      });
    }

    // Delay between lookups to avoid rate limiting
    if (i < names.length - 1) {
      await new Promise(resolve => setTimeout(resolve, LOOKUP_DELAY));
    }
  }

  return results;
}

/**
 * Filter results to show only available domains
 * @param {Array} results - Results from checkDomains
 * @returns {Array}
 */
export function filterAvailable(results) {
  return results.filter(r => r.available && !r.error);
}

/**
 * Group results by availability status
 * @param {Array} results - Results from checkDomains
 * @returns {{available: Array, taken: Array, errors: Array}}
 */
export function groupResults(results) {
  return {
    available: results.filter(r => r.available && !r.error),
    taken: results.filter(r => !r.available && !r.error),
    errors: results.filter(r => r.error),
  };
}
