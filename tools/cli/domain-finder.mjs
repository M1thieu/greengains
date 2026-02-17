#!/usr/bin/env node

/**
 * Domain Finder CLI - Interactive domain availability checker with AI
 */

import inquirer from 'inquirer';
import chalk from 'chalk';
import ora from 'ora';
import { writeFileSync } from 'fs';
import { checkDomains, filterAvailable, groupResults } from '../core/domain-checker.js';
import { generateNames, generateNamesManual } from '../core/name-generator.js';
import { NAME_STRATEGIES, SUPPORTED_TLDS } from '../core/config.js';

const BANNER = `
${chalk.cyan.bold('╔═══════════════════════════════════════╗')}
${chalk.cyan.bold('║')}  ${chalk.white.bold('🎯 Domain Finder AI')}              ${chalk.cyan.bold('║')}
${chalk.cyan.bold('║')}  ${chalk.gray('Find available domains with AI')}   ${chalk.cyan.bold('║')}
${chalk.cyan.bold('╚═══════════════════════════════════════╝')}
`;

async function main() {
  console.clear();
  console.log(BANNER);

  // Main menu
  const { mode } = await inquirer.prompt([{
    type: 'list',
    name: 'mode',
    message: 'What do you want to do?',
    choices: [
      { name: '🤖 Generate names with AI', value: 'generate-ai' },
      { name: '📝 Generate names manually (no AI)', value: 'generate-manual' },
      { name: '✅ Check specific domains', value: 'check-manual' },
      { name: '📄 Check from file', value: 'check-file' },
      { name: '❌ Exit', value: 'exit' },
    ],
  }]);

  if (mode === 'exit') {
    console.log(chalk.gray('\nGoodbye! 👋\n'));
    process.exit(0);
  }

  switch (mode) {
    case 'generate-ai':
      await generateWithAI();
      break;
    case 'generate-manual':
      await generateManually();
      break;
    case 'check-manual':
      await checkManual();
      break;
    case 'check-file':
      await checkFromFile();
      break;
  }

  // Ask to continue
  const { continue: shouldContinue } = await inquirer.prompt([{
    type: 'confirm',
    name: 'continue',
    message: 'Continue with another search?',
    default: true,
  }]);

  if (shouldContinue) {
    await main();
  } else {
    console.log(chalk.gray('\nGoodbye! 👋\n'));
  }
}

/**
 * Generate names with AI and check availability
 */
async function generateWithAI() {
  console.log(chalk.cyan('\n🤖 AI-Powered Name Generation\n'));

  // Get API key
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    console.log(chalk.red('❌ ANTHROPIC_API_KEY environment variable not set!\n'));
    console.log(chalk.gray('Set it with:'));
    console.log(chalk.yellow('export ANTHROPIC_API_KEY=your-key-here\n'));
    return;
  }

  // Get user preferences
  const answers = await inquirer.prompt([
    {
      type: 'input',
      name: 'concept',
      message: 'What concept/product?',
      default: 'ambient sensors, passive monitoring',
    },
    {
      type: 'input',
      name: 'style',
      message: 'What style?',
      default: 'abstract, 1-syllable, professional, not too explicit',
    },
    {
      type: 'list',
      name: 'strategy',
      message: 'Name generation strategy?',
      choices: [
        { name: 'All strategies (mixed)', value: NAME_STRATEGIES.ALL },
        { name: 'Greek letters (Delta, Sigma, Lambda...)', value: NAME_STRATEGIES.GREEK_LETTERS },
        { name: 'Abstract words (drift, pulse, mist...)', value: NAME_STRATEGIES.ABSTRACT_WORDS },
        { name: 'Phonetic variants (flo, synq, glo...)', value: NAME_STRATEGIES.PHONETIC_VARIANTS },
        { name: 'Ambient concepts', value: NAME_STRATEGIES.AMBIENT_CONCEPTS },
      ],
    },
    {
      type: 'number',
      name: 'count',
      message: 'How many names to generate?',
      default: 50,
    },
    {
      type: 'list',
      name: 'tld',
      message: 'Which TLD to check?',
      choices: SUPPORTED_TLDS,
      default: '.io',
    },
  ]);

  // Generate names with AI
  const spinner = ora('Generating names with Claude AI...').start();

  try {
    const names = await generateNames({
      concept: answers.concept,
      style: answers.style,
      strategy: answers.strategy,
      count: answers.count,
      apiKey,
    });

    spinner.succeed(`Generated ${names.length} names in ${chalk.cyan(names.length > 0 ? 'success' : 'error')}`);

    if (names.length === 0) {
      console.log(chalk.yellow('\n⚠️  No names generated. Try different parameters.\n'));
      return;
    }

    // Show preview
    console.log(chalk.gray('\nGenerated names (preview):'));
    console.log(chalk.cyan(names.slice(0, 10).join(', ') + '...\n'));

    // Check availability
    await checkAvailability(names, answers.tld);

  } catch (error) {
    spinner.fail('Failed to generate names');
    console.log(chalk.red(`\n❌ Error: ${error.message}\n`));
  }
}

/**
 * Generate names manually without AI
 */
async function generateManually() {
  console.log(chalk.cyan('\n📝 Manual Name Generation\n'));

  const answers = await inquirer.prompt([
    {
      type: 'list',
      name: 'strategy',
      message: 'Name generation strategy?',
      choices: [
        { name: 'All strategies (mixed)', value: NAME_STRATEGIES.ALL },
        { name: 'Greek letters', value: NAME_STRATEGIES.GREEK_LETTERS },
        { name: 'Abstract words', value: NAME_STRATEGIES.ABSTRACT_WORDS },
        { name: 'Phonetic variants', value: NAME_STRATEGIES.PHONETIC_VARIANTS },
        { name: 'Ambient concepts', value: NAME_STRATEGIES.AMBIENT_CONCEPTS },
      ],
    },
    {
      type: 'number',
      name: 'count',
      message: 'How many names?',
      default: 30,
    },
    {
      type: 'list',
      name: 'tld',
      message: 'Which TLD to check?',
      choices: SUPPORTED_TLDS,
      default: '.io',
    },
  ]);

  const names = generateNamesManual(answers.strategy, answers.count);

  console.log(chalk.gray('\nGenerated names (preview):'));
  console.log(chalk.cyan(names.slice(0, 10).join(', ') + '...\n'));

  await checkAvailability(names, answers.tld);
}

/**
 * Check specific domains entered manually
 */
async function checkManual() {
  const answers = await inquirer.prompt([
    {
      type: 'input',
      name: 'domains',
      message: 'Enter domain names (comma-separated):',
      validate: (input) => input.trim().length > 0 || 'Please enter at least one domain',
    },
    {
      type: 'list',
      name: 'tld',
      message: 'Which TLD to check?',
      choices: SUPPORTED_TLDS,
      default: '.io',
    },
  ]);

  const names = answers.domains.split(',').map(d => d.trim()).filter(Boolean);
  await checkAvailability(names, answers.tld);
}

/**
 * Check domains from a file
 */
async function checkFromFile() {
  const { filename, tld } = await inquirer.prompt([
    {
      type: 'input',
      name: 'filename',
      message: 'File path:',
      default: 'names.txt',
    },
    {
      type: 'list',
      name: 'tld',
      message: 'Which TLD to check?',
      choices: SUPPORTED_TLDS,
      default: '.io',
    },
  ]);

  try {
    const { readFileSync } = await import('fs');
    const content = readFileSync(filename, 'utf-8');
    const names = content.split('\n')
      .map(l => l.trim())
      .filter(l => l && !l.startsWith('#'));

    await checkAvailability(names, tld);
  } catch (error) {
    console.log(chalk.red(`\n❌ Error reading file: ${error.message}\n`));
  }
}

/**
 * Check availability of domains
 */
async function checkAvailability(names, tld) {
  console.log(chalk.cyan(`\n🔍 Checking ${names.length} domains for ${tld} availability...\n`));

  const spinner = ora('Starting domain checks...').start();
  const results = [];

  const progressResults = await checkDomains(names, tld, (progress) => {
    const { current, total, result } = progress;
    const percent = Math.round((current / total) * 100);

    if (result.available) {
      spinner.text = `[${current}/${total}] ${chalk.green('✓')} ${result.domain} ${chalk.green('AVAILABLE')}`;
    } else if (result.error) {
      spinner.text = `[${current}/${total}] ${chalk.yellow('?')} ${result.domain} ${chalk.yellow('ERROR')}`;
    } else {
      spinner.text = `[${current}/${total}] ${chalk.gray('✗')} ${result.domain} taken`;
    }

    results.push(result);
  });

  spinner.stop();

  // Show results summary
  const grouped = groupResults(results);

  console.log(chalk.cyan('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'));
  console.log(chalk.white.bold('📊 RESULTS SUMMARY\n'));

  console.log(`${chalk.green('✓')} Available: ${chalk.green.bold(grouped.available.length)}`);
  console.log(`${chalk.gray('✗')} Taken: ${chalk.gray(grouped.taken.length)}`);
  console.log(`${chalk.yellow('?')} Errors: ${chalk.yellow(grouped.errors.length)}`);

  if (grouped.available.length > 0) {
    console.log(chalk.green.bold('\n🎉 AVAILABLE DOMAINS:\n'));
    grouped.available.forEach(r => {
      console.log(chalk.green(`   ✓ ${r.domain}`));
    });
  } else {
    console.log(chalk.yellow('\n⚠️  No available domains found.\n'));
  }

  // Save results
  const filename = `results-${Date.now()}.json`;
  writeFileSync(filename, JSON.stringify({ results, grouped }, null, 2));
  console.log(chalk.gray(`\n💾 Results saved to: ${filename}\n`));
}

// Run CLI
main().catch(error => {
  console.error(chalk.red('\n❌ Fatal error:'), error);
  process.exit(1);
});
