// Storage wrapper for Archive Extension

import { STORAGE_KEYS, BATCH_CONFIG } from '../shared/constants.js';
import { getExtensionAPI } from '../shared/utils.js';

class StorageManager {
    constructor() {
        this.api = getExtensionAPI();
    }

    /**
     * Get a value from local storage
     * @param {string} key - Storage key
     * @param {*} defaultValue - Default value if not found
     * @returns {Promise<*>} Stored value or default
     */
    async get(key, defaultValue = null) {
        const result = await this.api.storage.local.get(key);
        return result[key] !== undefined ? result[key] : defaultValue;
    }

    /**
     * Set a value in local storage
     * @param {string} key - Storage key
     * @param {*} value - Value to store
     */
    async set(key, value) {
        await this.api.storage.local.set({ [key]: value });
    }

    /**
     * Remove a value from local storage
     * @param {string} key - Storage key
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
}

// Export singleton instance
export const storage = new StorageManager();
export default storage;
