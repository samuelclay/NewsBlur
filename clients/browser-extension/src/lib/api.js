// NewsBlur API Client for Archive Extension

import { API_BASE_URL, API_ENDPOINTS, STORAGE_KEYS } from '../shared/constants.js';
import { getExtensionAPI } from '../shared/utils.js';

class NewsBlurAPI {
    constructor() {
        this.baseUrl = API_BASE_URL;
        this.token = null;
    }

    /**
     * Initialize the API client, loading token from storage
     */
    async init() {
        const api = getExtensionAPI();
        const result = await api.storage.local.get(STORAGE_KEYS.AUTH_TOKEN);
        this.token = result[STORAGE_KEYS.AUTH_TOKEN] || null;
        return this.token !== null;
    }

    /**
     * Set the authentication token
     * @param {string} token - OAuth token
     */
    async setToken(token) {
        this.token = token;
        const api = getExtensionAPI();
        await api.storage.local.set({ [STORAGE_KEYS.AUTH_TOKEN]: token });
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
     * Make an API request
     * @param {string} endpoint - API endpoint path
     * @param {object} options - Fetch options
     * @returns {Promise<object>} Response data
     */
    async request(endpoint, options = {}) {
        const url = `${this.baseUrl}${endpoint}`;

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

// Export singleton instance
export const api = new NewsBlurAPI();
export default api;
