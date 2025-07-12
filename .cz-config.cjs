'use strict';

module.exports = {
  types: [
    { value: ':sparkles: feature', name: '✨  feature      :  A new feature' },
    { value: ':bug: fix', name: '🐛  fix          :  Fix a bug' },
    {
      value: ':memo: docs',
      name: '📝  docs         :  Documentation only changes',
    },
    {
      value: ':lipstick: style',
      name: '💄  style        :  Formatting, e.g., spaces, semicolons',
    },
    {
      value: ':recycle: refactor',
      name: '🛠   refactor     :  Code refactoring, distinct from features or fixes',
    },
    {
      value: ':zap: perf',
      name: '⚡  perf         :  Performance improvements',
    },
    {
      value: ':wrench: config',
      name: '🔧  config       :  Modify configuration files',
    },
    {
      value: ':white_check_mark: test',
      name: '✅  test         :  Add a test',
    },
    {
      value: ':rewind: revert',
      name: '⏪  revert       :  Revert code changes',
    },
    {
      value: ':construction: wip',
      name: '🚧  wip          :  Work in progress',
    },
    {
      value: ':twisted_rightwards_arrows: merge',
      name: '🔀  merge        :  Merge code',
    },
    { value: ':package: build', name: '📦  build        :  Build or release' },
    { value: ':fire: prune', name: '🔥  prune        :  Remove code/files' },
    {
      value: ':bookmark: release',
      name: '🔖  release      :  Release a new version',
    },
    {
      value: ':poop: poo',
      name: '💩  poo          :  Write suboptimal code to be optimized',
    },
    { value: ':tada: init', name: '🎉  init         :  Initial commit' },
    { value: ':rocket: deploy', name: '🚀  deploy       :  Deploy changes' },
    {
      value: ':lock: security',
      name: '🔒  security     :  Address security or privacy issues',
    },
    {
      value: ':closed_lock_with_key secrets:',
      name: '🔐  secrets      :  Add or update secrets',
    },
    {
      value: ':construction_worker: cli',
      name: '👷  cli          :  Add or update CI build system',
    },
    {
      value: ':arrow_up: dependencies',
      name: '⬆   dependencies :  Upgrade dependencies',
    },
    {
      value: ':arrow_down: dependencies',
      name: '⬇   dependencies :  Downgrade dependencies',
    },
    {
      value: ':pushpin: dependencies',
      name: '📌  dependencies :  Pin dependencies to specific versions',
    },
    {
      value: ':heavy_plus_sign: dependencies',
      name: '➕  dependencies :  Add a dependency',
    },
    {
      value: ':heavy_minus_sign: dependencies',
      name: '➖  dependencies :  Remove a dependency',
    },
    {
      value: ':hammer: script',
      name: '🔨  script       :  Add or update development scripts',
    },
    {
      value: ':globe_with_meridians: globe',
      name: '🌐  globe        :  Internationalization and localization',
    },
    { value: ':pencil2: typos', name: '✏   typos        :  Fix typos' },
    {
      value: ':alien: code',
      name: '👽  alien        :  Update code due to external API changes',
    },
    {
      value: ':truck: rename',
      name: '🚚  rename       :  Move or rename resources (e.g., files, paths, routes)',
    },
    {
      value: ':page_facing_up: license',
      name: '📄  license      :  Add or update license',
    },
    {
      value: ':bento: assets',
      name: '🍱  assets       :  Add or update assets',
    },
    {
      value: ':iphone: design',
      name: '📱  design       :  Work on responsive design',
    },
    {
      value: ':camera_flash: snapshots',
      name: '📸  snapshots    :  Add or update snapshots',
    },
    { value: ':coffin: code', name: '⚰   code         :  Remove dead code' },
    { value: ':clown_face: mock', name: '🤡  mock         :  Mock things' },
  ],

  scopes: [
    'config',
    'frontend',
    'backend',
    'build',
    'docs',
    'style',
    'cli',
    'api',
    'tests',
    'ci',
    'deps',
  ],

  allowCustomScopes: true,
  allowBreakingChanges: ['feat', 'fix', 'refactor', 'perf'],

  allowTicketNumber: false,
  isTicketNumberRequired: false,
  ticketNumberPrefix: 'TICKET-',
  ticketNumberRegExp: '\\d{1,5}',

  footerPrefix: ['Closes', 'Fixes', 'Resolves'],

  skipEmptyScopes: true,

  messages: {
    type: 'Select the type of your commit:',
    scope: 'Select the scope affected (optional):',
    customScope:
      'Enter the module or scope affected by this commit (optional):',
    subject: 'Short description of the commit:',
    body: 'Long description of the commit, use "|" for line breaks (optional):',
    breaking: 'Breaking changes description (optional):',
    footer: 'Reference closed issues, e.g., #31, #34 (optional):',
    confirmCommit: 'Confirm commit message? (y/n)',
  },

  upperCaseSubject: true,
  subjectLimit: 100,
  breaklineChar: '|',
};
