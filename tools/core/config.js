/**
 * Configuration for domain checker
 */

export const WHOIS_SERVERS = {
  '.com': 'whois.verisign-grs.com',
  '.io': 'whois.nic.io',
  '.co': 'whois.nic.co',
};

/**
 * TLDs that must be checked via RDAP HTTP API instead of WHOIS TCP.
 */
export const RDAP_ENDPOINTS = {
  '.app': 'https://pubapi.registry.google/rdap/domain/',
  '.dev': 'https://pubapi.registry.google/rdap/domain/',
};

export const SUPPORTED_TLDS = [...new Set([
  ...Object.keys(WHOIS_SERVERS),
  ...Object.keys(RDAP_ENDPOINTS),
])];

export const DEFAULT_TLD = '.io';
export const WHOIS_PORT = 43;
export const WHOIS_TIMEOUT = 10000; // 10 seconds
export const LOOKUP_DELAY = 1200; // 1.2 seconds between lookups

/**
 * Name generation strategies
 */
export const NAME_STRATEGIES = {
  GREEK_LETTERS: 'greek-letters',
  ABSTRACT_WORDS: 'abstract-words',
  PHONETIC_VARIANTS: 'phonetic-variants',
  AMBIENT_CONCEPTS: 'ambient-concepts',
  ALL: 'all',
};

/**
 * Greek letters with their scientific meanings
 */
export const GREEK_LETTERS = {
  delta: { symbol: 'Δ', meaning: 'Change/Variation in sensor data' },
  theta: { symbol: 'Θ', meaning: 'Temperature sensing' },
  lambda: { symbol: 'Λ', meaning: 'Wavelength/Light sensing' },
  mu: { symbol: 'μ', meaning: 'Microparticles/Air quality' },
  sigma: { symbol: 'Σ', meaning: 'Aggregation/Sum of readings' },
  tau: { symbol: 'τ', meaning: 'Time/Continuous measurement' },
  phi: { symbol: 'Φ', meaning: 'Flux/Flow (air/particle movement)' },
  psi: { symbol: 'Ψ', meaning: 'Pressure/Force' },
};

/**
 * Concept categories for ambient sensing
 */
export const AMBIENT_CONCEPTS = {
  MOVEMENT: ['drift', 'shift', 'glide', 'float', 'sway'],
  OBSERVATION: ['trace', 'track', 'glance', 'peek', 'scope', 'scan'],
  COVERAGE: ['span', 'range', 'reach', 'field', 'zone', 'space'],
  TIME: ['pulse', 'beat', 'pace', 'tick', 'lapse'],
  NATURE: ['moss', 'dew', 'mist', 'fog', 'haze', 'shade', 'glow'],
  LIGHT: ['lux', 'beam', 'ray', 'gleam', 'hue'],
  SIGNALS: ['crest', 'swell', 'surge', 'wave', 'tide'],
};
