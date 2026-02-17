/**
 * Branding Constants
 *
 * Single source of truth for app name and branding across the backend.
 * Update these values when rebranding - all references will update automatically.
 *
 * CRITICAL: Package ID and Firebase Project ID must NEVER change to avoid reinstalls.
 */

export const BRANDING = {
  /**
   * App display name - used in logs, error messages, etc.
   * UPDATE THIS when rebranding
   */
  APP_NAME: process.env.APP_NAME || 'GreenGains',

  /**
   * App display name for user-facing contexts
   * UPDATE THIS when rebranding
   */
  APP_DISPLAY_NAME: process.env.APP_DISPLAY_NAME || 'GreenGains',

  /**
   * Package identifier - MUST NEVER CHANGE
   * Changing this would require all users to reinstall the app
   */
  PACKAGE_ID: 'com.eremat.greengains',

  /**
   * Firebase project identifier - MUST NEVER CHANGE
   * Changing this would break authentication for all users
   */
  FIREBASE_PROJECT_ID: 'greengains-f46f7',

  /**
   * Tagline for branding/marketing
   * UPDATE THIS when rebranding
   */
  TAGLINE: 'Passive ambient sensor monitoring',
} as const;

// Type export for use in other files
export type Branding = typeof BRANDING;
