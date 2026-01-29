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
};
