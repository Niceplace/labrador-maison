module.exports = {
  // Platform configuration (self-hosted only)
  platform: 'github',
  timezone: 'America/Toronto',

  // Extend recommended base configuration
  extends: ['config:recommended'],

  // Repositories in scope
  repositories: ['Niceplace/labrador-maison'],

  // Disable onboarding since we have explicit config
  onboarding: false,
  requireConfig: 'optional',

  // Make config validation errors fatal (exit with non-zero code)
  configValidationError: true,

  // Enable debug logging for more context when errors occur
  logLevel: 'debug',

  // Reuse existing Config Warning issue instead of creating new ones
  configWarningReuseIssue: true,
};
