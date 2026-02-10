// NewsBlur Archive Extension Constants

// Default production URL
export const DEFAULT_SERVER_URL = 'https://newsblur.com';

// Kept for backwards compatibility - use getServerUrl() from storage for dynamic URL
export const API_BASE_URL = DEFAULT_SERVER_URL;

export const API_ENDPOINTS = {
    INGEST: '/api/archive/ingest',
    BATCH_INGEST: '/api/archive/batch_ingest',
    LIST: '/api/archive/list',
    CATEGORIES: '/api/archive/categories',
    STATS: '/api/archive/stats',
    BLOCKLIST: '/api/archive/blocklist',
    // Category management
    CATEGORIES_MERGE: '/api/archive/categories/merge',
    CATEGORIES_RENAME: '/api/archive/categories/rename',
    CATEGORIES_SPLIT: '/api/archive/categories/split',
    CATEGORIES_SUGGEST_MERGES: '/api/archive/categories/suggest-merges',
    CATEGORIES_BULK_CATEGORIZE: '/api/archive/categories/bulk-categorize'
};

// OAuth config is built dynamically based on server URL
export const OAUTH_CONFIG = {
    CLIENT_ID: 'newsblur-archive-extension',
    SCOPE: 'archive'
};

// Helper to build OAuth authorize URL
export function getOAuthAuthorizeUrl(serverUrl) {
    return `${serverUrl}/oauth/authorize`;
}

export const STORAGE_KEYS = {
    AUTH_TOKEN: 'authToken',
    USER_BLOCKLIST: 'userBlocklist',
    PENDING_ARCHIVES: 'pendingArchives',
    LAST_SYNC: 'lastSync',
    SETTINGS: 'settings',
    SERVER_URL: 'serverUrl',
    USE_CUSTOM_SERVER: 'useCustomServer'
};

// Time thresholds in milliseconds
export const TIME_THRESHOLDS = {
    MIN_TIME_ON_PAGE: 5000,  // 5 seconds minimum to archive
    SYNC_DEBOUNCE: 5000,     // 5 seconds debounce for sync
    BATCH_MAX_AGE: 30000,    // 30 seconds max age before force sync
    IDLE_TIMEOUT: 60000,     // 60 seconds of no activity = idle
    ACTIVE_TIME_HEARTBEAT: 10000  // Report active time to service worker every 10 seconds
};

export const BATCH_CONFIG = {
    MAX_BATCH_SIZE: 10,
    MAX_QUEUE_SIZE: 100
};

// Default blocked domains
export const DEFAULT_BLOCKED_DOMAINS = [
    // Banking & Finance
    'chase.com', 'bankofamerica.com', 'wellsfargo.com', 'citi.com',
    'capitalone.com', 'usbank.com', 'pnc.com', 'schwab.com',
    'fidelity.com', 'vanguard.com', 'paypal.com', 'venmo.com',
    'coinbase.com', 'robinhood.com', 'etrade.com', 'tdameritrade.com',
    'ally.com', 'discover.com', 'americanexpress.com', 'barclays.com',
    'hsbc.com', 'santander.com', 'usaa.com', 'navyfederal.org',
    'synchrony.com', 'marcus.com', 'sofi.com', 'chime.com',

    // Medical & Health
    'mychart.com', 'patient.portal', 'healthgrades.com',
    'zocdoc.com', 'webmd.com', 'mayoclinic.org', 'cvs.com',
    'walgreens.com', 'express-scripts.com', 'optum.com',
    'anthem.com', 'cigna.com', 'aetna.com', 'unitedhealthcare.com',
    'bluecrossblueshift.com', 'kaiser.com',

    // Email Providers
    'mail.google.com', 'outlook.live.com', 'mail.yahoo.com',
    'protonmail.com', 'fastmail.com', 'tutanota.com', 'mail.aol.com',
    'zoho.com/mail', 'icloud.com/mail',

    // Password Managers
    '1password.com', 'lastpass.com', 'bitwarden.com', 'dashlane.com',
    'keeper.com', 'nordpass.com',

    // Social Media Direct Messages
    'messages.google.com', 'web.whatsapp.com', 'web.telegram.org',
    'discord.com', 'slack.com', 'messenger.com',

    // Video Calls
    'zoom.us', 'meet.google.com', 'teams.microsoft.com',

    // Cloud Storage (sensitive folders)
    'drive.google.com', 'dropbox.com', 'onedrive.live.com', 'box.com',

    // HR & Payroll
    'workday.com', 'adp.com', 'gusto.com', 'paylocity.com',
    'paychex.com', 'bamboohr.com',

    // Government
    'irs.gov', 'ssa.gov', 'dmv.', 'courts.', '.gov/login',

    // Crypto
    'metamask.io', 'phantom.app', 'ledger.com', 'trezor.io'
];

// URL patterns to block
export const DEFAULT_BLOCKED_PATTERNS = [
    /\/cart/i,
    /\/checkout/i,
    /\/payment/i,
    /\/billing/i,
    /\/login/i,
    /\/signin/i,
    /\/signup/i,
    /\/register/i,
    /\/auth/i,
    /\/oauth/i,
    /\/account\/settings/i,
    /\/account\/security/i,
    /\/admin\//i,
    /\/dashboard\/settings/i,
    /\/profile\/edit/i,
    /\/password/i,
    /\/2fa/i,
    /\/mfa/i,
    /\/verify/i,
    /\/confirm/i,
    /\/unsubscribe/i
];

// Internal/local patterns
export const INTERNAL_PATTERNS = [
    /^localhost/i,
    /^127\.0\.0\./,
    /^192\.168\./,
    /^10\./,
    /\.local$/i,
    /\.internal$/i,
    /\.corp$/i,
    /\.intranet$/i
];

// Browser schemes to ignore
export const IGNORED_SCHEMES = [
    'chrome://',
    'chrome-extension://',
    'moz-extension://',
    'edge://',
    'about:',
    'file://',
    'data:',
    'javascript:',
    'blob:'
];

export const BROWSER_INFO = {
    CHROME: 'chrome',
    FIREFOX: 'firefox',
    EDGE: 'edge',
    SAFARI: 'safari'
};
