// NewsBlur API Client for Archive Extension

import { DEFAULT_SERVER_URL, API_ENDPOINTS, STORAGE_KEYS } from '../shared/constants.js';
import { getExtensionAPI } from '../shared/utils.js';

class NewsBlurAPI {
    constructor() {
        this.baseUrl = DEFAULT_SERVER_URL;
        this.token = null;
    }

    /**
     * Initialize the API client, loading token and server URL from storage
     */
    async init() {
        const api = getExtensionAPI();
        const result = await api.storage.local.get([
            STORAGE_KEYS.AUTH_TOKEN,
            STORAGE_KEYS.USE_CUSTOM_SERVER,
            STORAGE_KEYS.SERVER_URL
        ]);
        this.token = result[STORAGE_KEYS.AUTH_TOKEN] || null;

        // Load server URL
        if (result[STORAGE_KEYS.USE_CUSTOM_SERVER] && result[STORAGE_KEYS.SERVER_URL]) {
            this.baseUrl = result[STORAGE_KEYS.SERVER_URL];
        } else {
            this.baseUrl = DEFAULT_SERVER_URL;
        }

        return this.token !== null;
    }

    /**
     * Update the base URL (called when server settings change)
     * @param {string} url - New base URL
     */
    setBaseUrl(url) {
        this.baseUrl = url;
    }

    /**
     * Get the current base URL
     * @returns {string} Current base URL
     */
    getBaseUrl() {
        return this.baseUrl;
    }

    /**
     * Set the authentication token and related data
     * @param {string} token - OAuth access token
     * @param {string} refreshToken - OAuth refresh token (optional)
     * @param {number} expiresIn - Token expiry in seconds (optional)
     */
    async setToken(token, refreshToken = null, expiresIn = null) {
        this.token = token;
        const api = getExtensionAPI();

        const data = { [STORAGE_KEYS.AUTH_TOKEN]: token };
        if (refreshToken) {
            data.refreshToken = refreshToken;
        }
        if (expiresIn) {
            data.tokenExpiry = Date.now() + (expiresIn * 1000);
        }

        await api.storage.local.set(data);
    }

    /**
     * Clear the authentication token
     */
    async clearToken() {
        this.token = null;
        const api = getExtensionAPI();
        await api.storage.local.remove(STORAGE_KEYS.AUTH_TOKEN);
    }

    /**
     * Check if user is authenticated
     * @returns {boolean} True if authenticated
     */
    isAuthenticated() {
        return this.token !== null;
    }

    /**
     * Check if running in a service worker context
     * @returns {boolean} True if in service worker
     */
    isServiceWorker() {
        return typeof ServiceWorkerGlobalScope !== 'undefined' && self instanceof ServiceWorkerGlobalScope;
    }

    /**
     * Make an API request
     * @param {string} endpoint - API endpoint path
     * @param {object} options - Fetch options
     * @returns {Promise<object>} Response data
     */
    async request(endpoint, options = {}) {
        let url = `${this.baseUrl}${endpoint}`;

        // In service worker context, localhost HTTPS fails due to self-signed certs
        // Convert to HTTP and adjust port for Django direct access
        // Worktree ports: HTTPS = 8443 + offset, Django HTTP = 8000 + offset
        // So HTTP_PORT = HTTPS_PORT - 443
        if (this.isServiceWorker() && url.startsWith('https://localhost')) {
            const urlObj = new URL(url);
            const httpsPort = parseInt(urlObj.port) || 443;
            // Calculate Django direct HTTP port
            const httpPort = httpsPort === 443 ? 80 : httpsPort - 443;
            urlObj.protocol = 'http:';
            urlObj.port = httpPort.toString();
            url = urlObj.toString();
            console.log('NewsBlur Archive: Using HTTP for localhost in service worker:', url);
        }

        const headers = {
            'Content-Type': 'application/x-www-form-urlencoded',
            ...options.headers
        };

        // Add authorization if we have a token
        if (this.token) {
            headers['Authorization'] = `Bearer ${this.token}`;
        }

        const fetchOptions = {
            ...options,
            headers,
            credentials: 'include'
        };

        try {
            const response = await fetch(url, fetchOptions);

            if (response.status === 401) {
                // Token expired or invalid
                await this.clearToken();
                throw new Error('Authentication required');
            }

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }

            return await response.json();
        } catch (error) {
            console.error(`API request failed: ${endpoint}`, error);
            throw error;
        }
    }

    /**
     * Ingest a single archived page
     * @param {object} archive - Archive data
     * @returns {Promise<object>} Response data
     */
    async ingest(archive) {
        const body = new URLSearchParams();
        body.append('url', archive.url);
        body.append('title', archive.title || '');
        if (archive.content) body.append('content', archive.content);
        if (archive.contentLength) body.append('content_length', archive.contentLength.toString());
        if (archive.faviconUrl) body.append('favicon_url', archive.faviconUrl);
        if (archive.timeOnPage) body.append('time_on_page', archive.timeOnPage.toString());
        if (archive.browser) body.append('browser', archive.browser);
        if (archive.extensionVersion) body.append('extension_version', archive.extensionVersion);

        return this.request(API_ENDPOINTS.INGEST, {
            method: 'POST',
            body: body.toString()
        });
    }

    /**
     * Batch ingest multiple archived pages
     * @param {object[]} archives - Array of archive data
     * @returns {Promise<object>} Response data
     */
    async batchIngest(archives) {
        const body = new URLSearchParams();
        body.append('archives', JSON.stringify(archives));

        return this.request(API_ENDPOINTS.BATCH_INGEST, {
            method: 'POST',
            body: body.toString()
        });
    }

    /**
     * Get list of archived pages
     * @param {object} params - Query parameters
     * @returns {Promise<object>} Response data
     */
    async listArchives(params = {}) {
        const queryParams = new URLSearchParams(params);
        return this.request(`${API_ENDPOINTS.LIST}?${queryParams.toString()}`);
    }

    /**
     * Get category breakdown
     * @returns {Promise<object>} Response data
     */
    async getCategories() {
        return this.request(API_ENDPOINTS.CATEGORIES);
    }

    /**
     * Get archive statistics
     * @returns {Promise<object>} Response data
     */
    async getStats() {
        return this.request(API_ENDPOINTS.STATS);
    }

    /**
     * Get user's blocklist
     * @returns {Promise<object>} Response data
     */
    async getBlocklist() {
        return this.request(API_ENDPOINTS.BLOCKLIST);
    }

    /**
     * Update user's blocklist
     * @param {string[]} blockedDomains - Domains to block
     * @param {string[]} blockedPatterns - URL patterns to block
     * @returns {Promise<object>} Response data
     */
    async updateBlocklist(blockedDomains, blockedPatterns) {
        const body = new URLSearchParams();
        body.append('blocked_domains', JSON.stringify(blockedDomains));
        body.append('blocked_patterns', JSON.stringify(blockedPatterns));

        return this.request(API_ENDPOINTS.BLOCKLIST, {
            method: 'POST',
            body: body.toString()
        });
    }
}

// Export singleton instance and class
export const api = new NewsBlurAPI();
export { NewsBlurAPI };
export default api;
