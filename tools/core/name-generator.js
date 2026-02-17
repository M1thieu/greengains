/**
 * AI-powered name generator using Claude API
 */

import Anthropic from '@anthropic-ai/sdk';
import { GREEK_LETTERS, AMBIENT_CONCEPTS, NAME_STRATEGIES } from './config.js';

/**
 * Generate names using Claude API
 * @param {object} options - Generation options
 * @param {string} options.concept - The core concept (e.g., "ambient sensors")
 * @param {string} options.style - Style preferences (e.g., "abstract, 1-syllable")
 * @param {string} options.strategy - Strategy to use (from NAME_STRATEGIES)
 * @param {number} options.count - Number of names to generate
 * @param {string} options.apiKey - Anthropic API key
 * @returns {Promise<string[]>}
 */
export async function generateNames({ concept, style, strategy, count = 50, apiKey }) {
  if (!apiKey) {
    throw new Error('Anthropic API key required. Set ANTHROPIC_API_KEY environment variable.');
  }

  const anthropic = new Anthropic({ apiKey });

  const prompt = buildPrompt(concept, style, strategy, count);

  const message = await anthropic.messages.create({
    model: 'claude-sonnet-4-20250514',
    max_tokens: 2048,
    messages: [{
      role: 'user',
      content: prompt,
    }],
  });

  // Extract names from response
  const responseText = message.content[0].text;
  const names = parseNamesFromResponse(responseText);

  return names.slice(0, count);
}

/**
 * Build prompt for Claude based on strategy
 */
function buildPrompt(concept, style, strategy, count) {
  const baseContext = `Generate ${count} unique 1-syllable brand names for: ${concept}

Style requirements: ${style}

CRITICAL RULES:
- ONLY 1 syllable (strict)
- NOT too explicit or descriptive
- Professional for B2B + consumer use
- Pronounceable in English and French
- Abstract but meaningful (like Stripe, Slack, Notion)
- Must relate subtly to the concept
- Avoid: sensor, green, eco, monitor, data (too explicit)

`;

  let strategyPrompt = '';

  switch (strategy) {
    case NAME_STRATEGIES.GREEK_LETTERS:
      strategyPrompt = `Use Greek letters as inspiration (Delta, Theta, Lambda, Mu, Sigma, Tau, Phi, Psi).
Create subtle variations and twists (NOT the letters themselves):
- Delta (Δ = change) → dela, delz, delt
- Sigma (Σ = aggregation) → siga, sigz, sigt
- Lambda (Λ = light) → lama, lamz, lamb

Examples: siga, lamz, delto, sigmo, theyo`;
      break;

    case NAME_STRATEGIES.ABSTRACT_WORDS:
      strategyPrompt = `Use abstract English words that subtly relate to the concept.
Think: movement, observation, nature, light, signals.
NOT explicit sensor words, but evocative concepts.

Examples: drift, mist, pulse, trace, gleam, span, flux`;
      break;

    case NAME_STRATEGIES.PHONETIC_VARIANTS:
      strategyPrompt = `Create phonetic variants and intentional misspellings (like Lyft, Fiverr).
Twist existing words to make them unique but pronounceable.

Examples: flo (flow), glo (glow), dryft (drift), trase (trace), synq (sync)`;
      break;

    case NAME_STRATEGIES.AMBIENT_CONCEPTS:
      strategyPrompt = `Focus on ambient sensing concepts:
- Passive monitoring (drift, flow, float)
- Environmental (air, mist, dew, haze)
- Data patterns (pulse, wave, signal, flux)
- Subtle observation (peek, glance, trace)

Make them abstract enough to not be limiting.`;
      break;

    default:
      strategyPrompt = `Mix all strategies:
- Greek letter derivatives
- Abstract words
- Phonetic variants
- Ambient concepts

Create diverse, creative options.`;
  }

  return baseContext + strategyPrompt + `

OUTPUT FORMAT:
Just list the names, one per line, no explanations:
name1
name2
name3
...`;
}

/**
 * Parse names from Claude's response
 */
function parseNamesFromResponse(text) {
  // Extract lines that look like single-word names
  const lines = text.split('\n');
  const names = [];

  for (const line of lines) {
    const trimmed = line.trim().toLowerCase();

    // Skip empty lines, explanations, numbers, etc.
    if (!trimmed ||
        trimmed.length > 15 ||
        trimmed.startsWith('#') ||
        trimmed.includes(' ') ||
        trimmed.includes(':') ||
        /^\d/.test(trimmed)) {
      continue;
    }

    // Extract just the name if it has punctuation
    const name = trimmed.replace(/[^a-z]/g, '');
    if (name.length >= 2) {
      names.push(name);
    }
  }

  return [...new Set(names)]; // Remove duplicates
}

/**
 * Generate names without AI (fallback/manual mode)
 */
export function generateNamesManual(strategy, count = 30) {
  const names = [];

  switch (strategy) {
    case NAME_STRATEGIES.GREEK_LETTERS:
      names.push(...generateGreekVariants());
      break;

    case NAME_STRATEGIES.ABSTRACT_WORDS:
      names.push(...generateAbstractWords());
      break;

    case NAME_STRATEGIES.PHONETIC_VARIANTS:
      names.push(...generatePhoneticVariants());
      break;

    case NAME_STRATEGIES.AMBIENT_CONCEPTS:
      names.push(...generateAmbientConcepts());
      break;

    default:
      names.push(
        ...generateGreekVariants(),
        ...generateAbstractWords(),
        ...generatePhoneticVariants(),
        ...generateAmbientConcepts()
      );
  }

  // Shuffle and return requested count
  return names.sort(() => Math.random() - 0.5).slice(0, count);
}

function generateGreekVariants() {
  const variants = [];
  const bases = Object.keys(GREEK_LETTERS);
  const suffixes = ['a', 'o', 'z', 't', 'x'];

  for (const base of bases) {
    const short = base.slice(0, 3);
    for (const suffix of suffixes) {
      variants.push(short + suffix);
    }
  }

  return variants;
}

function generateAbstractWords() {
  return Object.values(AMBIENT_CONCEPTS).flat();
}

function generatePhoneticVariants() {
  const words = ['flow', 'glow', 'drift', 'trace', 'pulse', 'sync', 'wave'];
  const variants = [];

  for (const word of words) {
    // Remove vowels at end
    if (word.length > 3) {
      variants.push(word.slice(0, -1));
    }
    // Add z
    variants.push(word.replace(/s$/, 'z'));
    // Replace y with i
    variants.push(word.replace(/y/, 'i'));
  }

  return variants;
}

function generateAmbientConcepts() {
  return [
    'drift', 'shift', 'glide', 'pulse', 'trace',
    'mist', 'haze', 'glow', 'beam', 'flux',
    'span', 'scope', 'peek', 'zone', 'flow',
  ];
}
