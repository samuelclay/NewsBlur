// NewsBlur Archive Extension Utilities

import {
    IGNORED_SCHEMES,
    DEFAULT_BLOCKED_DOMAINS,
    DEFAULT_BLOCKED_PATTERNS,
    INTERNAL_PATTERNS,
    BROWSER_INFO
} from './constants.js';

/**
 * Get the current browser type
 * @returns {string} Browser identifier
 */
export function getBrowser() {
    if (typeof chrome !== 'undefined' && chrome.runtime) {
        if (navigator.userAgent.includes('Edg/')) {
            return BROWSER_INFO.EDGE;
        }
        if (navigator.userAgent.includes('Firefox/')) {
            return BROWSER_INFO.FIREFOX;
        }
        return BROWSER_INFO.CHROME;
    }
    if (typeof browser !== 'undefined') {
        return BROWSER_INFO.FIREFOX;
    }
    return BROWSER_INFO.CHROME;
}

/**
 * Get the extension API (chrome or browser)
 * @returns {object} Extension API
 */
export function getExtensionAPI() {
    return typeof browser !== 'undefined' ? browser : chrome;
}

/**
 * Check if a URL should be ignored (browser internal pages, etc.)
 * @param {string} url - URL to check
 * @returns {boolean} True if URL should be ignored
 */
export function shouldIgnoreUrl(url) {
    if (!url) return true;

    // Check ignored schemes
    for (const scheme of IGNORED_SCHEMES) {
        if (url.startsWith(scheme)) {
            return true;
        }
    }

    return false;
}

/**
 * Extract domain from URL
 * @param {string} url - Full URL
 * @returns {string} Domain name
 */
export function extractDomain(url) {
    try {
        const urlObj = new URL(url);
        return urlObj.hostname.toLowerCase();
    } catch (e) {
        return '';
    }
}

/**
 * Check if a URL is blocked by domain or pattern
 * @param {string} url - URL to check
 * @param {string[]} userBlockedDomains - Additional user-specified blocked domains
 * @returns {boolean} True if URL is blocked
 */
export function isBlocked(url, userBlockedDomains = []) {
    if (!url) return true;

    const domain = extractDomain(url);
    if (!domain) return true;

    // Check internal patterns
    for (const pattern of INTERNAL_PATTERNS) {
        if (pattern.test(domain)) {
            return true;
        }
    }

    // Check default blocked domains
    const allBlockedDomains = [...DEFAULT_BLOCKED_DOMAINS, ...userBlockedDomains];
    for (const blockedDomain of allBlockedDomains) {
        if (domain === blockedDomain || domain.endsWith('.' + blockedDomain)) {
            return true;
        }
    }

    // Check URL patterns
    for (const pattern of DEFAULT_BLOCKED_PATTERNS) {
        if (pattern.test(url)) {
            return true;
        }
    }

    return false;
}

/**
 * Normalize a URL by removing tracking parameters and standardizing format
 * @param {string} url - URL to normalize
 * @returns {string} Normalized URL
 */
export function normalizeUrl(url) {
    try {
        const urlObj = new URL(url);

        // Remove common tracking parameters
        const trackingParams = [
            'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
            'fbclid', 'gclid', 'dclid', 'msclkid', 'twclid', 'li_fat_id',
            'mc_cid', 'mc_eid', 'ref', 'ref_src', 'source', '_ga',
            'oly_enc_id', 'oly_anon_id', 'vero_id', 'wickedid',
            '__s', '_hsenc', '_hsmi', 'trk', 'mkt_tok'
        ];

        for (const param of trackingParams) {
            urlObj.searchParams.delete(param);
        }

        // Remove hash if it looks like tracking
        if (urlObj.hash && /^#(utm_|ref=|source=)/.test(urlObj.hash)) {
            urlObj.hash = '';
        }

        // Convert to lowercase hostname
        urlObj.hostname = urlObj.hostname.toLowerCase();

        // Remove trailing slash from path
        if (urlObj.pathname.endsWith('/') && urlObj.pathname !== '/') {
            urlObj.pathname = urlObj.pathname.slice(0, -1);
        }

        return urlObj.toString();
    } catch (e) {
        return url;
    }
}

/**
 * Generate a hash of a string (for URL deduplication)
 * @param {string} str - String to hash
 * @returns {Promise<string>} SHA-256 hash as hex string
 */
export async function hashString(str) {
    const encoder = new TextEncoder();
    const data = encoder.encode(str);
    const hashBuffer = await crypto.subtle.digest('SHA-256', data);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

/**
 * Format a date as relative time
 * @param {Date|number} date - Date to format
 * @returns {string} Relative time string
 */
export function formatRelativeTime(date) {
    const now = Date.now();
    const timestamp = date instanceof Date ? date.getTime() : date;
    const diff = now - timestamp;

    const minutes = Math.floor(diff / 60000);
    const hours = Math.floor(diff / 3600000);
    const days = Math.floor(diff / 86400000);

    if (minutes < 1) return 'Just now';
    if (minutes < 60) return `${minutes}m ago`;
    if (hours < 24) return `${hours}h ago`;
    if (days < 7) return `${days}d ago`;
    if (days < 30) return `${Math.floor(days / 7)}w ago`;

    return new Date(timestamp).toLocaleDateString();
}

/**
 * Truncate text to a maximum length
 * @param {string} text - Text to truncate
 * @param {number} maxLength - Maximum length
 * @returns {string} Truncated text
 */
export function truncateText(text, maxLength = 100) {
    if (!text || text.length <= maxLength) return text;
    return text.slice(0, maxLength - 3) + '...';
}

/**
 * Debounce a function
 * @param {Function} func - Function to debounce
 * @param {number} wait - Wait time in ms
 * @returns {Function} Debounced function
 */
export function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

/**
 * Check if running in incognito/private mode
 * @returns {Promise<boolean>} True if in incognito mode
 */
export async function isIncognito() {
    const api = getExtensionAPI();
    return new Promise((resolve) => {
        if (api.extension && api.extension.inIncognitoContext !== undefined) {
            resolve(api.extension.inIncognitoContext);
        } else {
            resolve(false);
        }
    });
}

/**
 * Get extension version
 * @returns {string} Extension version
 */
export function getExtensionVersion() {
    const api = getExtensionAPI();
    return api.runtime.getManifest().version;
}
