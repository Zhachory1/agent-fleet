#!/usr/bin/env node
import { spawnSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const binDir = dirname(fileURLToPath(import.meta.url));
const root = resolve(binDir, '..');
const installSh = resolve(root, 'install.sh');
const rawArgs = process.argv.slice(2);

if (rawArgs[0] === 'home') {
  console.log(root);
  process.exit(0);
}

function normalizeArgs(args) {
  if (args.length === 0 || args[0] === 'help') return ['--help'];
  if (args[0] === 'install') return withCopyDefault(args.slice(1));
  if (args[0] === 'uninstall') return [...args.slice(1), '--uninstall'];
  return withCopyDefault(args);
}

function withCopyDefault(args) {
  if (args.includes('--uninstall') || args.includes('--copy')) return args;
  return [...args, '--copy'];
}

const result = spawnSync('bash', [installSh, ...normalizeArgs(rawArgs)], {
  stdio: 'inherit',
  env: {
    ...process.env,
    AGENT_FLEET_NPM: '1',
  },
});

if (result.error) {
  if (result.error.code === 'ENOENT') {
    console.error('agent-fleet: bash is required but was not found on PATH.');
  } else {
    console.error(`agent-fleet: failed to run installer: ${result.error.message}`);
  }
  process.exit(1);
}

process.exit(result.status ?? 1);
