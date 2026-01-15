// Storage wrapper for Archive Extension

import { STORAGE_KEYS, BATCH_CONFIG, DEFAULT_SERVER_URL } from '../shared/constants.js';
import { getExtensionAPI } from '../shared/utils.js';

class StorageManager {
    constructor() {
        this.api = getExtensionAPI();
    }

    /**
     * Get a value from local storage
     * @param {string|string[]} key - Storage key or array of keys
     * @param {*} defaultValue - Default value if not found (only used for single key)
     * @returns {Promise<*>} Stored value, default, or object with multiple values
     */
    async get(key, defaultValue = null) {
        const result = await this.api.storage.local.get(key);
        // If array of keys was passed, return the result object directly
        if (Array.isArray(key)) {
            return result;
        }
        return result[key] !== undefined ? result[key] : defaultValue;
    }

    /**
     * Set a value or multiple values in local storage
     * @param {string|object} keyOrItems - Storage key or object of key-value pairs
     * @param {*} value - Value to store (only used if keyOrItems is a string)
     */
    async set(keyOrItems, value) {
        if (typeof keyOrItems === 'object') {
            await this.api.storage.local.set(keyOrItems);
        } else {
            await this.api.storage.local.set({ [keyOrItems]: value });
        }
    }

    /**
     * Remove a value or multiple values from local storage
     * @param {string|string[]} key - Storage key or array of keys
     */
    async remove(key) {
        await this.api.storage.local.remove(key);
    }

    /**
     * Get all pending archives from queue
     * @returns {Promise<object[]>} Pending archives
     */
    async getPendingArchives() {
        return this.get(STORAGE_KEYS.PENDING_ARCHIVES, []);
    }

    /**
     * Add an archive to the pending queue
     * @param {object} archive - Archive to add
     */
    async addPendingArchive(archive) {
        const pending = await this.getPendingArchives();

        // Check if URL already exists in pending (dedupe)
        const existingIndex = pending.findIndex(a => a.url === archive.url);
        if (existingIndex >= 0) {
            // Update existing entry
            pending[existingIndex] = { ...pending[existingIndex], ...archive };
        } else {
            pending.push(archive);
        }

        // Limit queue size
        if (pending.length > BATCH_CONFIG.MAX_QUEUE_SIZE) {
            pending.splice(0, pending.length - BATCH_CONFIG.MAX_QUEUE_SIZE);
        }

        await this.set(STORAGE_KEYS.PENDING_ARCHIVES, pending);
    }

    /**
     * Get and remove archives from the queue for syncing
     * @param {number} count - Number of archives to get
     * @returns {Promise<object[]>} Archives removed from queue
     */
    async popPendingArchives(count = BATCH_CONFIG.MAX_BATCH_SIZE) {
        const pending = await this.getPendingArchives();
        const toSync = pending.splice(0, count);
        await this.set(STORAGE_KEYS.PENDING_ARCHIVES, pending);
        return toSync;
    }

    /**
     * Return archives to the front of the queue (on sync failure)
     * @param {object[]} archives - Archives to return
     */
    async returnPendingArchives(archives) {
        const pending = await this.getPendingArchives();
        await this.set(STORAGE_KEYS.PENDING_ARCHIVES, [...archives, ...pending]);
    }

    /**
     * Get user's custom blocklist
     * @returns {Promise<string[]>} Blocked domains
     */
    async getUserBlocklist() {
        return this.get(STORAGE_KEYS.USER_BLOCKLIST, []);
    }

    /**
     * Set user's custom blocklist
     * @param {string[]} domains - Domains to block
     */
    async setUserBlocklist(domains) {
        await this.set(STORAGE_KEYS.USER_BLOCKLIST, domains);
    }

    /**
     * Add domain to user's blocklist
     * @param {string} domain - Domain to add
     */
    async addToBlocklist(domain) {
        const blocklist = await this.getUserBlocklist();
        if (!blocklist.includes(domain)) {
            blocklist.push(domain);
            await this.setUserBlocklist(blocklist);
        }
    }

    /**
     * Remove domain from user's blocklist
     * @param {string} domain - Domain to remove
     */
    async removeFromBlocklist(domain) {
        const blocklist = await this.getUserBlocklist();
        const index = blocklist.indexOf(domain);
        if (index >= 0) {
            blocklist.splice(index, 1);
            await this.setUserBlocklist(blocklist);
        }
    }

    /**
     * Get user settings
     * @returns {Promise<object>} Settings object
     */
    async getSettings() {
        return this.get(STORAGE_KEYS.SETTINGS, {
            enabled: true,
            syncEnabled: true,
            minTimeOnPage: 5
        });
    }

    /**
     * Update user settings
     * @param {object} settings - Settings to merge
     */
    async updateSettings(settings) {
        const current = await this.getSettings();
        await this.set(STORAGE_KEYS.SETTINGS, { ...current, ...settings });
    }

    /**
     * Get last sync timestamp
     * @returns {Promise<number|null>} Timestamp or null
     */
    async getLastSync() {
        return this.get(STORAGE_KEYS.LAST_SYNC, null);
    }

    /**
     * Set last sync timestamp
     * @param {number} timestamp - Timestamp
     */
    async setLastSync(timestamp = Date.now()) {
        await this.set(STORAGE_KEYS.LAST_SYNC, timestamp);
    }

    /**
     * Clear all extension data
     */
    async clearAll() {
        await this.api.storage.local.clear();
    }

    /**
     * Clear pending archives only
     */
    async clearPendingArchives() {
        await this.set(STORAGE_KEYS.PENDING_ARCHIVES, []);
    }

    /**
     * Get the configured server URL
     * @returns {Promise<string>} Server URL
     */
    async getServerUrl() {
        const useCustom = await this.get(STORAGE_KEYS.USE_CUSTOM_SERVER, false);
        if (useCustom) {
            const customUrl = await this.get(STORAGE_KEYS.SERVER_URL, '');
            if (customUrl) {
                return customUrl;
            }
        }
        return DEFAULT_SERVER_URL;
    }

    /**
     * Set whether to use custom server
     * @param {boolean} useCustom - Whether to use custom server
     */
    async setUseCustomServer(useCustom) {
        await this.set(STORAGE_KEYS.USE_CUSTOM_SERVER, useCustom);
    }

    /**
     * Get whether using custom server
     * @returns {Promise<boolean>} True if using custom server
     */
    async getUseCustomServer() {
        return this.get(STORAGE_KEYS.USE_CUSTOM_SERVER, false);
    }

    /**
     * Set custom server URL
     * @param {string} url - Custom server URL
     */
    async setCustomServerUrl(url) {
        await this.set(STORAGE_KEYS.SERVER_URL, url);
    }

    /**
     * Get custom server URL
     * @returns {Promise<string>} Custom server URL or empty string
     */
    async getCustomServerUrl() {
        return this.get(STORAGE_KEYS.SERVER_URL, '');
    }

    /**
     * Get auth token
     * @returns {Promise<string|null>} Auth token or null
     */
    async getToken() {
        return this.get(STORAGE_KEYS.AUTH_TOKEN, null);
    }

    /**
     * Set auth token
     * @param {string} token - Auth token
     */
    async setToken(token) {
        await this.set(STORAGE_KEYS.AUTH_TOKEN, token);
    }

    /**
     * Remove auth token
     */
    async removeToken() {
        await this.remove(STORAGE_KEYS.AUTH_TOKEN);
    }

    /**
     * Set a single setting value
     * @param {string} key - Setting key
     * @param {*} value - Setting value
     */
    async setSetting(key, value) {
        const settings = await this.getSettings();
        settings[key] = value;
        await this.set(STORAGE_KEYS.SETTINGS, settings);
    }

    /**
     * Add domain to user blocklist
     * @param {string} domain - Domain to add
     */
    async addToUserBlocklist(domain) {
        await this.addToBlocklist(domain);
    }

    /**
     * Remove domain from user blocklist
     * @param {string} domain - Domain to remove
     */
    async removeFromUserBlocklist(domain) {
        await this.removeFromBlocklist(domain);
    }
}

// Export singleton instance and class
export const storage = new StorageManager();
export const Storage = StorageManager;
export default storage;
