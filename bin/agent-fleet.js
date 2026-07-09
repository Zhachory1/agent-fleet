#!/usr/bin/env node
'use strict';

const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const packageRoot = path.resolve(__dirname, '..');
const versionFile = path.join(packageRoot, 'VERSION');
const packageFile = path.join(packageRoot, 'package.json');
const runtimeHome = path.resolve(process.env.AGENT_FLEET_NPM_HOME || path.join(os.homedir(), '.agent-fleet'));

const runtimeDirs = ['ship-agents', 'skills', 'prompts', 'bin', 'lib', 'examples'];
const runtimeFiles = ['install.sh', 'install.manifest.json', 'VERSION', 'README.md', 'INSTALL.md', 'LICENSE', 'package.json'];

function readVersion() {
  try {
    const version = fs.readFileSync(versionFile, 'utf8').trim();
    if (version) return version;
  } catch (_) {
    // Fall through to package metadata.
  }
  return JSON.parse(fs.readFileSync(packageFile, 'utf8')).version;
}

function copyPath(from, to) {
  fs.mkdirSync(path.dirname(to), { recursive: true });
  fs.cpSync(from, to, { recursive: true, force: true, dereference: false });
}

function isPrivateOverlay(entry) {
  return entry === '_overlay.md' || entry === '_rokt-overlay.md';
}

function cleanAgentsDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
  for (const entry of fs.readdirSync(dir)) {
    if (isPrivateOverlay(entry)) continue;
    fs.rmSync(path.join(dir, entry), { recursive: true, force: true });
  }
}

function syncRuntimeHome() {
  const sourceRoot = fs.realpathSync(packageRoot);
  fs.mkdirSync(runtimeHome, { recursive: true });
  const targetRoot = fs.realpathSync(runtimeHome);
  if (sourceRoot === targetRoot) return runtimeHome;

  const sourceAgents = path.join(packageRoot, 'agents');
  const targetAgents = path.join(runtimeHome, 'agents');
  cleanAgentsDir(targetAgents);
  for (const entry of fs.readdirSync(sourceAgents)) {
    if (isPrivateOverlay(entry)) continue;
    copyPath(path.join(sourceAgents, entry), path.join(targetAgents, entry));
  }

  for (const dir of runtimeDirs) {
    const source = path.join(packageRoot, dir);
    if (!fs.existsSync(source)) continue;
    const target = path.join(runtimeHome, dir);
    fs.rmSync(target, { recursive: true, force: true });
    copyPath(source, target);
  }

  for (const file of runtimeFiles) {
    const source = path.join(packageRoot, file);
    if (fs.existsSync(source)) copyPath(source, path.join(runtimeHome, file));
  }

  return runtimeHome;
}

function printHelp() {
  const version = readVersion();
  process.stdout.write(`agent-fleet v${version}

Usage:
  agent-fleet install [install options]
  agent-fleet home
  agent-fleet --version
  agent-fleet --help

Commands:
  install   Install agent-fleet payloads into Claude Code, Codex, Cave, Cursor,
            opencode, or a generic TUI resource directory. Syncs the package to
            a stable runtime home, then runs the compatibility installer with
            copy mode so one-shot npx installs do not point at npm cache paths.
            Run \`agent-fleet install --help\` for tool flags.
  home      Sync and print the stable runtime home path.

Examples:
  npx @zhachory1/agent-fleet install --tool claude
  npx @zhachory1/agent-fleet install --tool codex
  npx @zhachory1/agent-fleet install --tool opencode
  npx @zhachory1/agent-fleet install --tool cave --user
  npx @zhachory1/agent-fleet install --dir ~/.mewrite

Fallback if npm/npx is unavailable:
  bash install.sh --tool claude
`);
}

function runInstall(args) {
  const home = syncRuntimeHome();
  const installScript = path.join(home, 'install.sh');
  if (!fs.existsSync(installScript)) {
    process.stderr.write(`agent-fleet: missing runtime install.sh at ${installScript}\n`);
    return 1;
  }
  const env = { ...process.env, AGENT_FLEET_INSTALL_COPY: '1' };
  const result = spawnSync('bash', [installScript, ...args], { stdio: 'inherit', env });
  if (result.error) {
    process.stderr.write(`agent-fleet: failed to execute bash install.sh: ${result.error.message}\n`);
    return 1;
  }
  if (result.signal) {
    process.kill(process.pid, result.signal);
    return 1;
  }
  return result.status ?? 0;
}

const args = process.argv.slice(2);
const command = args[0];

if (!command || command === '--help' || command === '-h' || command === 'help') {
  printHelp();
  process.exit(0);
}

if (command === '--version' || command === '-V' || command === 'version') {
  process.stdout.write(`${readVersion()}\n`);
  process.exit(0);
}

if (command === 'home') {
  try {
    process.stdout.write(`${syncRuntimeHome()}\n`);
    process.exit(0);
  } catch (error) {
    process.stderr.write(`agent-fleet: failed to sync runtime home: ${error.message}\n`);
    process.exit(1);
  }
}

if (command === 'install') {
  try {
    process.exit(runInstall(args.slice(1)));
  } catch (error) {
    process.stderr.write(`agent-fleet: install failed: ${error.message}\n`);
    process.exit(1);
  }
}

process.stderr.write(`agent-fleet: unknown command '${command}' (try --help or 'install --help')\n`);
process.exit(1);
