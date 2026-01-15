// NewsBlur Archive Extension - Options Page Script

import { DEFAULT_SERVER_URL, OAUTH_CONFIG, DEFAULT_BLOCKED_DOMAINS, STORAGE_KEYS, getOAuthAuthorizeUrl } from '../shared/constants.js';
import { extractDomain, getExtensionAPI, getExtensionVersion } from '../shared/utils.js';
import { NewsBlurAPI } from '../lib/api.js';
import { Storage } from '../lib/storage.js';

const extApi = getExtensionAPI();
const api = new NewsBlurAPI();
const storage = new Storage();

// DOM Elements
let elements = {};

/**
 * Initialize the options page
 */
async function init() {
    cacheElements();
    setupEventListeners();
    await loadServerConfig();
    await loadSettings();
    await loadAccountStatus();
    await loadBlocklist();
    await loadDataStats();
    setVersion();
}

/**
 * Cache DOM element references
 */
function cacheElements() {
    elements = {
        // Server
        serverProduction: document.getElementById('serverProduction'),
        serverCustom: document.getElementById('serverCustom'),
        customServerRow: document.getElementById('customServerRow'),
        customServerUrl: document.getElementById('customServerUrl'),
        currentServerDisplay: document.getElementById('currentServerDisplay'),

        // Account
        accountStatus: document.getElementById('accountStatus'),
        connectButton: document.getElementById('connectButton'),
        disconnectButton: document.getElementById('disconnectButton'),

        // Settings
        enabled: document.getElementById('enabled'),
        syncEnabled: document.getElementById('syncEnabled'),
        minTimeOnPage: document.getElementById('minTimeOnPage'),

        // Blocklist
        newBlockedDomain: document.getElementById('newBlockedDomain'),
        addBlockedDomain: document.getElementById('addBlockedDomain'),
        blocklist: document.getElementById('blocklist'),

        // Data
        pendingArchives: document.getElementById('pendingArchives'),
        syncNow: document.getElementById('syncNow'),
        clearData: document.getElementById('clearData'),

        // About
        version: document.getElementById('version'),
    };
}

/**
 * Set up event listeners
 */
function setupEventListeners() {
    // Server configuration
    elements.serverProduction.addEventListener('change', handleServerModeChange);
    elements.serverCustom.addEventListener('change', handleServerModeChange);
    elements.customServerUrl.addEventListener('change', handleCustomUrlChange);
    elements.customServerUrl.addEventListener('blur', handleCustomUrlChange);

    // Account buttons
    elements.connectButton.addEventListener('click', handleConnect);
    elements.disconnectButton.addEventListener('click', handleDisconnect);

    // Settings changes
    elements.enabled.addEventListener('change', handleSettingChange);
    elements.syncEnabled.addEventListener('change', handleSettingChange);
    elements.minTimeOnPage.addEventListener('change', handleSettingChange);

    // Blocklist
    elements.addBlockedDomain.addEventListener('click', handleAddBlockedDomain);
    elements.newBlockedDomain.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
            handleAddBlockedDomain();
        }
    });

    // Data actions
    elements.syncNow.addEventListener('click', handleSyncNow);
    elements.clearData.addEventListener('click', handleClearData);
}

/**
 * Load server configuration
 */
async function loadServerConfig() {
    const useCustom = await storage.getUseCustomServer();
    const customUrl = await storage.getCustomServerUrl();

    if (useCustom) {
        elements.serverCustom.checked = true;
        elements.customServerRow.classList.remove('hidden');
    } else {
        elements.serverProduction.checked = true;
        elements.customServerRow.classList.add('hidden');
    }

    if (customUrl) {
        elements.customServerUrl.value = customUrl;
    }

    updateServerDisplay();
}

/**
 * Update the server display text
 */
async function updateServerDisplay() {
    const serverUrl = await storage.getServerUrl();
    try {
        const url = new URL(serverUrl);
        elements.currentServerDisplay.textContent = url.host;
    } catch (e) {
        elements.currentServerDisplay.textContent = serverUrl;
    }
}

/**
 * Handle server mode change (production vs custom)
 */
async function handleServerModeChange(event) {
    const useCustom = event.target.value === 'custom';

    if (useCustom) {
        elements.customServerRow.classList.remove('hidden');
    } else {
        elements.customServerRow.classList.add('hidden');
    }

    await storage.setUseCustomServer(useCustom);
    await updateServerDisplay();

    // Notify background script of server change
    extApi.runtime.sendMessage({
        action: 'serverChanged'
    });
}

/**
 * Handle custom URL change
 */
async function handleCustomUrlChange() {
    let url = elements.customServerUrl.value.trim();

    if (!url) {
        return;
    }

    // Add https:// if no protocol
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://' + url;
        elements.customServerUrl.value = url;
    }

    // Remove trailing slash
    url = url.replace(/\/+$/, '');
    elements.customServerUrl.value = url;

    await storage.setCustomServerUrl(url);
    await updateServerDisplay();

    // Notify background script of server change
    extApi.runtime.sendMessage({
        action: 'serverChanged'
    });
}

/**
 * Load current settings
 */
async function loadSettings() {
    const settings = await storage.getSettings();

    elements.enabled.checked = settings.enabled !== false;
    elements.syncEnabled.checked = settings.syncEnabled !== false;
    elements.minTimeOnPage.value = settings.minTimeOnPage || 5;
}

/**
 * Load account connection status
 */
async function loadAccountStatus() {
    const token = await storage.getToken();

    if (token) {
        // Verify token is still valid
        try {
            const stats = await api.getStats();
            if (stats.code === 0) {
                showConnected();
                return;
            }
        } catch (error) {
            console.error('Token validation failed:', error);
        }
    }

    showDisconnected();
}

/**
 * Show connected state
 */
function showConnected() {
    const statusIndicator = elements.accountStatus.querySelector('.status-indicator');
    const statusText = elements.accountStatus.querySelector('.status-text');

    statusIndicator.classList.add('connected');
    statusIndicator.classList.remove('disconnected');
    statusText.textContent = 'Connected to NewsBlur';

    elements.connectButton.classList.add('hidden');
    elements.disconnectButton.classList.remove('hidden');
}

/**
 * Show disconnected state
 */
function showDisconnected() {
    const statusIndicator = elements.accountStatus.querySelector('.status-indicator');
    const statusText = elements.accountStatus.querySelector('.status-text');

    statusIndicator.classList.remove('connected');
    statusIndicator.classList.add('disconnected');
    statusText.textContent = 'Not connected';

    elements.connectButton.classList.remove('hidden');
    elements.disconnectButton.classList.add('hidden');
}

/**
 * Load blocklist
 */
async function loadBlocklist() {
    elements.blocklist.innerHTML = '<div class="loading">Loading...</div>';

    try {
        const userBlocklist = await storage.getUserBlocklist();
        const allBlocked = [...DEFAULT_BLOCKED_DOMAINS, ...userBlocklist];

        renderBlocklist(allBlocked, userBlocklist);
    } catch (error) {
        console.error('Error loading blocklist:', error);
        elements.blocklist.innerHTML = '<div class="blocklist-empty">Failed to load blocklist</div>';
    }
}

/**
 * Render blocklist items
 */
function renderBlocklist(allDomains, userDomains) {
    if (allDomains.length === 0) {
        elements.blocklist.innerHTML = '<div class="blocklist-empty">No blocked domains</div>';
        return;
    }

    // Sort: user-added first, then defaults
    const sortedDomains = [
        ...userDomains.sort(),
        ...DEFAULT_BLOCKED_DOMAINS.filter(d => !userDomains.includes(d)).sort()
    ];

    elements.blocklist.innerHTML = '';

    sortedDomains.forEach(domain => {
        const isUserAdded = userDomains.includes(domain);
        const item = document.createElement('div');
        item.className = 'blocklist-item';

        item.innerHTML = `
            <span class="blocklist-domain">${domain}</span>
            ${isUserAdded
                ? `<button class="blocklist-remove" data-domain="${domain}">Remove</button>`
                : '<span style="color: #aaa; font-size: 11px;">Default</span>'
            }
        `;

        if (isUserAdded) {
            item.querySelector('.blocklist-remove').addEventListener('click', () => {
                handleRemoveBlockedDomain(domain);
            });
        }

        elements.blocklist.appendChild(item);
    });
}

/**
 * Load data statistics
 */
async function loadDataStats() {
    try {
        const pending = await storage.getPendingArchives();
        elements.pendingArchives.textContent = pending.length;
    } catch (error) {
        console.error('Error loading stats:', error);
    }
}

/**
 * Set version number
 */
function setVersion() {
    const version = getExtensionVersion();
    elements.version.textContent = version || '1.0.0';
}

/**
 * Handle OAuth connect
 */
async function handleConnect() {
    try {
        elements.connectButton.disabled = true;
        elements.connectButton.textContent = 'Connecting...';

        const serverUrl = await storage.getServerUrl();
        const redirectUri = extApi.identity.getRedirectURL();
        const authUrl = new URL(getOAuthAuthorizeUrl(serverUrl));
        authUrl.searchParams.set('client_id', OAUTH_CONFIG.CLIENT_ID);
        authUrl.searchParams.set('redirect_uri', redirectUri);
        authUrl.searchParams.set('response_type', 'token');
        authUrl.searchParams.set('scope', OAUTH_CONFIG.SCOPE);

        const responseUrl = await extApi.identity.launchWebAuthFlow({
            url: authUrl.toString(),
            interactive: true
        });

        // Extract token from response URL
        const hashParams = new URLSearchParams(
            new URL(responseUrl).hash.substring(1)
        );
        const token = hashParams.get('access_token');

        if (token) {
            await storage.setToken(token);
            showConnected();
        } else {
            throw new Error('No access token received');
        }
    } catch (error) {
        console.error('Connect error:', error);
        alert('Failed to connect. Please try again.');
    } finally {
        elements.connectButton.disabled = false;
        elements.connectButton.textContent = 'Connect Account';
    }
}

/**
 * Handle disconnect
 */
async function handleDisconnect() {
    if (!confirm('Are you sure you want to disconnect your NewsBlur account?')) {
        return;
    }

    try {
        await storage.removeToken();
        showDisconnected();
    } catch (error) {
        console.error('Disconnect error:', error);
        alert('Failed to disconnect. Please try again.');
    }
}

/**
 * Handle setting change
 */
async function handleSettingChange(event) {
    const setting = event.target.id;
    let value;

    if (event.target.type === 'checkbox') {
        value = event.target.checked;
    } else if (event.target.type === 'select-one') {
        value = parseInt(event.target.value, 10);
    } else {
        value = event.target.value;
    }

    try {
        await storage.setSetting(setting, value);

        // Notify background script of settings change
        extApi.runtime.sendMessage({
            action: 'settingsChanged',
            settings: { [setting]: value }
        });
    } catch (error) {
        console.error('Error saving setting:', error);
    }
}

/**
 * Handle add blocked domain
 */
async function handleAddBlockedDomain() {
    const input = elements.newBlockedDomain;
    let domain = input.value.trim().toLowerCase();

    if (!domain) {
        return;
    }

    // Extract domain if full URL was entered
    if (domain.includes('/')) {
        domain = extractDomain(domain);
    }

    // Remove protocol if present
    domain = domain.replace(/^https?:\/\//, '').replace(/^www\./, '');

    // Basic validation
    if (!domain || !domain.includes('.')) {
        alert('Please enter a valid domain (e.g., example.com)');
        return;
    }

    try {
        await storage.addToUserBlocklist(domain);
        input.value = '';
        await loadBlocklist();

        // Notify background script
        extApi.runtime.sendMessage({
            action: 'blocklistChanged'
        });
    } catch (error) {
        console.error('Error adding blocked domain:', error);
        alert('Failed to add domain. Please try again.');
    }
}

/**
 * Handle remove blocked domain
 */
async function handleRemoveBlockedDomain(domain) {
    try {
        await storage.removeFromUserBlocklist(domain);
        await loadBlocklist();

        // Notify background script
        extApi.runtime.sendMessage({
            action: 'blocklistChanged'
        });
    } catch (error) {
        console.error('Error removing blocked domain:', error);
        alert('Failed to remove domain. Please try again.');
    }
}

/**
 * Handle sync now
 */
async function handleSyncNow() {
    elements.syncNow.disabled = true;
    elements.syncNow.textContent = 'Syncing...';

    try {
        const response = await extApi.runtime.sendMessage({ action: 'syncNow' });

        if (response && response.success) {
            await loadDataStats();
            alert('Sync completed successfully!');
        } else {
            throw new Error(response?.error || 'Sync failed');
        }
    } catch (error) {
        console.error('Sync error:', error);
        alert('Sync failed. Please try again.');
    } finally {
        elements.syncNow.disabled = false;
        elements.syncNow.textContent = 'Sync Now';
    }
}

/**
 * Handle clear data
 */
async function handleClearData() {
    if (!confirm('Are you sure you want to clear all local archive data? This will not affect data already synced to NewsBlur.')) {
        return;
    }

    try {
        await storage.clearPendingArchives();
        await loadDataStats();
        alert('Local data cleared successfully.');
    } catch (error) {
        console.error('Clear data error:', error);
        alert('Failed to clear data. Please try again.');
    }
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', init);
