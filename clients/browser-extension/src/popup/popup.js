// NewsBlur Archive Extension - Popup Script

import { DEFAULT_SERVER_URL, OAUTH_CONFIG, getOAuthAuthorizeUrl, BATCH_CONFIG } from '../shared/constants.js';
import { formatRelativeTime, truncateText, getExtensionAPI } from '../shared/utils.js';
import { storage } from '../lib/storage.js';

console.log('NewsBlur Archive: Popup script loaded');

const extApi = getExtensionAPI();
console.log('NewsBlur Archive: Extension API:', extApi ? 'available' : 'NOT FOUND');

// Current server URL (loaded from storage)
let currentServerUrl = DEFAULT_SERVER_URL;

// Localhost sync interval
let localhostSyncInterval = null;

// Port connection for real-time updates from service worker
let serviceWorkerPort = null;

// DOM Elements
const loginSection = document.getElementById('loginSection');
const mainSection = document.getElementById('mainSection');
const loginButton = document.getElementById('loginButton');
const settingsButton = document.querySelector('.settings-button');

const currentFavicon = document.getElementById('currentFavicon');
const currentTitle = document.getElementById('currentTitle');
const saveButton = document.getElementById('saveButton');
const shareButton = document.getElementById('shareButton');
const subscribeButton = document.getElementById('subscribeButton');

const archivedBadge = document.getElementById('archivedBadge');
const pendingBadge = document.getElementById('pendingBadge');
const statusText = document.getElementById('statusText');

const pendingCount = document.getElementById('pendingCount');
const totalArchived = document.getElementById('totalArchived');
const lastSync = document.getElementById('lastSync');

const recentList = document.getElementById('recentList');

// Footer elements
const serverBadge = document.getElementById('serverBadge');
const serverName = document.getElementById('serverName');
const searchArchivesLink = document.getElementById('searchArchivesLink');
const openArchiveLink = document.getElementById('openArchiveLink');
const aboutLink = document.getElementById('aboutLink');

/**
 * Initialize the popup
 */
async function init() {
    console.log('NewsBlur Archive: init() called');

    // Load server configuration first
    await loadServerConfig();
    console.log('NewsBlur Archive: Server config loaded');

    // Get status from background
    const status = await sendMessage({ action: 'getStatus' });

    if (status.authenticated) {
        showMainSection();
        await loadData(status);
        // Set up real-time connection for updates
        setupRealtimeConnection();
        // Set up localhost sync (popup handles sync for localhost servers)
        await setupLocalhostSync();
    } else {
        showLoginSection();
    }

    // Set up current tab info
    await loadCurrentTab();

    // Set up event listeners
    setupEventListeners();
}

/**
 * Set up port connection to service worker for real-time updates
 */
function setupRealtimeConnection() {
    try {
        serviceWorkerPort = extApi.runtime.connect({ name: 'popup' });

        serviceWorkerPort.onMessage.addListener((message) => {
            console.log('NewsBlur Archive: Received message from service worker:', message.type);

            if (message.type === 'archive:new') {
                handleNewArchives(message.data);
            }
        });

        serviceWorkerPort.onDisconnect.addListener(() => {
            console.log('NewsBlur Archive: Port disconnected, reconnecting...');
            // Reconnect after a short delay
            setTimeout(setupRealtimeConnection, 1000);
        });

        console.log('NewsBlur Archive: Real-time connection established');
    } catch (error) {
        console.error('NewsBlur Archive: Failed to setup real-time connection:', error);
    }
}

/**
 * Check if we're using a localhost server
 */
function isLocalhostServer() {
    return currentServerUrl.includes('localhost') || currentServerUrl.includes('127.0.0.1');
}

/**
 * Setup localhost sync - the popup handles syncing for localhost servers
 * because service workers have SSL certificate issues with localhost
 */
async function setupLocalhostSync() {
    if (!isLocalhostServer()) {
        console.log('NewsBlur Archive: Not localhost, service worker handles sync');
        return;
    }

    console.log('NewsBlur Archive: Localhost detected, popup will handle sync');

    // Sync immediately on popup open
    await syncPendingArchivesFromPopup();

    // Set up periodic sync while popup is open (every 3 seconds)
    localhostSyncInterval = setInterval(async () => {
        await syncPendingArchivesFromPopup();
    }, 3000);
}

/**
 * Sync pending archives directly from popup (for localhost)
 */
async function syncPendingArchivesFromPopup() {
    try {
        const archives = await storage.popPendingArchives(BATCH_CONFIG.MAX_BATCH_SIZE);

        if (archives.length === 0) {
            return;
        }

        console.log('NewsBlur Archive: Popup syncing', archives.length, 'archives to localhost');

        const token = await storage.getToken();
        if (!token) {
            console.log('NewsBlur Archive: No token, returning archives to queue');
            await storage.returnPendingArchives(archives);
            return;
        }

        const response = await fetch(`${currentServerUrl}/api/archive/batch_ingest`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${token}`
            },
            body: JSON.stringify({ archives })
        });

        const result = await response.json();

        if (result.code === 0) {
            console.log('NewsBlur Archive: Popup sync successful');
            await storage.setLastSync();

            // Handle new archives in the popup UI
            const successfulArchives = result.results ?
                result.results.filter(r => r.archive_id && !r.error) : [];
            if (successfulArchives.length > 0) {
                handleNewArchives({ archives: successfulArchives });
            }

            // Update pending count
            pendingCount.textContent = (await storage.getPendingArchives()).length;
        } else {
            console.error('NewsBlur Archive: Popup sync failed:', result.message);
            await storage.returnPendingArchives(archives);
        }
    } catch (error) {
        console.error('NewsBlur Archive: Popup sync error:', error);
    }
}

/**
 * Handle new archives received from service worker
 */
function handleNewArchives(data) {
    const newArchives = data.archives || [];

    if (newArchives.length === 0) return;

    console.log('NewsBlur Archive: Received', newArchives.length, 'new archives in real-time');

    // Prepend new archives to the recent list
    prependArchives(newArchives);

    // Update stats
    loadStats();

    // Update pending count (likely decreased since sync completed)
    sendMessage({ action: 'getStatus' }).then(status => {
        pendingCount.textContent = status.pendingCount || 0;
        if (status.lastSync) {
            lastSync.textContent = formatRelativeTime(status.lastSync);
        }
    });
}

/**
 * Prepend new archives to the recent list
 */
function prependArchives(archives) {
    archives.forEach(archive => {
        // Normalize the ID field
        if (archive.archive_id && !archive.id) {
            archive.id = archive.archive_id;
        }

        const item = document.createElement('div');
        item.className = 'recent-item';
        item.dataset.url = archive.url;

        const faviconHtml = archive.favicon_url
            ? `<img class="recent-favicon" src="${archive.favicon_url}" alt="">`
            : '<div class="recent-favicon-placeholder"></div>';

        const categoriesHtml = archive.ai_categories && archive.ai_categories.length > 0
            ? `<div class="recent-categories">
                ${archive.ai_categories.slice(0, 2).map(cat =>
                `<span class="category-pill">${cat}</span>`
            ).join('')}
               </div>`
            : '';

        const timeAgo = 'Just now';

        item.innerHTML = `
            ${faviconHtml}
            <div class="recent-content">
                <div class="recent-title">${truncateText(archive.title || 'Untitled', 60)}</div>
                <div class="recent-meta">
                    <span class="recent-domain">${archive.domain || ''}</span>
                    <span class="recent-time">${timeAgo}</span>
                </div>
                ${categoriesHtml}
            </div>
        `;

        item.addEventListener('click', () => {
            extApi.tabs.create({ url: archive.url });
        });

        // Insert at the beginning
        if (recentList.firstChild) {
            recentList.insertBefore(item, recentList.firstChild);
        } else {
            recentList.appendChild(item);
        }
    });

    // Remove excess items (keep max 10)
    while (recentList.children.length > 10) {
        recentList.removeChild(recentList.lastChild);
    }

    // Remove any "loading" or "empty" messages
    const loadingMsg = recentList.querySelector('.loading');
    const emptyMsg = recentList.querySelector('.empty-message');
    if (loadingMsg) loadingMsg.remove();
    if (emptyMsg) emptyMsg.remove();
}

/**
 * Load server configuration and update display
 */
async function loadServerConfig() {
    currentServerUrl = await storage.getServerUrl();
    const useCustom = await storage.getUseCustomServer();

    // Update server badge display
    try {
        const url = new URL(currentServerUrl);
        serverName.textContent = url.host;
    } catch (e) {
        serverName.textContent = currentServerUrl;
    }

    // Add custom class if using custom server
    if (useCustom) {
        serverBadge.classList.add('custom');
        serverBadge.title = 'Connected to custom server';
    } else {
        serverBadge.classList.remove('custom');
        serverBadge.title = 'Connected to NewsBlur';
    }
}

/**
 * Send message to background script
 */
function sendMessage(message) {
    return new Promise((resolve) => {
        extApi.runtime.sendMessage(message, resolve);
    });
}

/**
 * Show login section
 */
function showLoginSection() {
    loginSection.classList.remove('hidden');
    mainSection.classList.add('hidden');
}

/**
 * Show main section
 */
function showMainSection() {
    loginSection.classList.add('hidden');
    mainSection.classList.remove('hidden');
}

/**
 * Load current tab info
 */
async function loadCurrentTab() {
    try {
        const [tab] = await extApi.tabs.query({ active: true, currentWindow: true });
        if (tab) {
            currentTitle.textContent = truncateText(tab.title || 'Current Page', 50);
            if (tab.favIconUrl) {
                currentFavicon.src = tab.favIconUrl;
                currentFavicon.style.display = 'block';
            } else {
                currentFavicon.style.display = 'none';
            }
        }
    } catch (error) {
        console.error('Error loading current tab:', error);
    }
}

/**
 * Load data for main section
 */
async function loadData(status) {
    // Update stats
    pendingCount.textContent = status.pendingCount || 0;

    if (status.lastSync) {
        lastSync.textContent = formatRelativeTime(status.lastSync);
    } else {
        lastSync.textContent = 'Never';
    }

    // Load archives
    await loadRecentArchives();
    await loadStats();
}

/**
 * Load recent archives
 */
async function loadRecentArchives() {
    recentList.innerHTML = '<div class="loading">Loading...</div>';

    try {
        const response = await sendMessage({
            action: 'getArchives',
            params: { limit: 10 }
        });

        if (response.error) {
            throw new Error(response.error);
        }

        if (response.code === 0 && response.archives && response.archives.length > 0) {
            renderArchives(response.archives);
        } else {
            recentList.innerHTML = '<div class="empty-message">No archives yet. Browse the web to start building your archive.</div>';
        }
    } catch (error) {
        console.error('Error loading archives:', error);
        recentList.innerHTML = '<div class="empty-message">Failed to load archives</div>';
    }
}

/**
 * Load stats
 */
async function loadStats() {
    try {
        const response = await sendMessage({ action: 'getStats' });

        if (response.code === 0 && response.stats) {
            totalArchived.textContent = response.stats.total_archives || 0;
        }
    } catch (error) {
        console.error('Error loading stats:', error);
    }
}

/**
 * Render archives list
 */
function renderArchives(archives) {
    recentList.innerHTML = '';

    archives.forEach(archive => {
        const item = document.createElement('div');
        item.className = 'recent-item';
        item.dataset.url = archive.url;

        const faviconHtml = archive.favicon_url
            ? `<img class="recent-favicon" src="${archive.favicon_url}" alt="">`
            : '<div class="recent-favicon-placeholder"></div>';

        const categoriesHtml = archive.ai_categories && archive.ai_categories.length > 0
            ? `<div class="recent-categories">
                ${archive.ai_categories.slice(0, 2).map(cat =>
                `<span class="category-pill">${cat}</span>`
            ).join('')}
               </div>`
            : '';

        const timeAgo = archive.archived_date
            ? formatRelativeTime(new Date(archive.archived_date))
            : '';

        item.innerHTML = `
            ${faviconHtml}
            <div class="recent-content">
                <div class="recent-title">${truncateText(archive.title || 'Untitled', 60)}</div>
                <div class="recent-meta">
                    <span class="recent-domain">${archive.domain || ''}</span>
                    <span class="recent-time">${timeAgo}</span>
                </div>
                ${categoriesHtml}
            </div>
        `;

        item.addEventListener('click', () => {
            extApi.tabs.create({ url: archive.url });
        });

        recentList.appendChild(item);
    });
}

/**
 * Set up event listeners
 */
function setupEventListeners() {
    console.log('NewsBlur Archive: Setting up event listeners');
    console.log('NewsBlur Archive: settingsButton:', settingsButton);

    // Login button
    loginButton.addEventListener('click', handleLogin);

    // Settings button
    settingsButton.addEventListener('click', () => {
        console.log('NewsBlur Archive: Settings button clicked');
        extApi.runtime.openOptionsPage();
    });

    // Action buttons
    saveButton.addEventListener('click', handleSave);
    shareButton.addEventListener('click', handleShare);
    subscribeButton.addEventListener('click', handleSubscribe);

    // Footer links
    searchArchivesLink.addEventListener('click', (e) => {
        e.preventDefault();
        extApi.tabs.create({ url: `${currentServerUrl}/archive` });
    });

    openArchiveLink.addEventListener('click', (e) => {
        e.preventDefault();
        extApi.tabs.create({ url: `${currentServerUrl}/archive` });
    });

    aboutLink.addEventListener('click', (e) => {
        e.preventDefault();
        extApi.tabs.create({ url: `${currentServerUrl}/about` });
    });
}

/**
 * Handle OAuth login
 */
async function handleLogin() {
    try {
        const redirectUri = extApi.identity.getRedirectURL();
        const authUrl = new URL(getOAuthAuthorizeUrl(currentServerUrl));
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
            await sendMessage({ action: 'setToken', token });
            showMainSection();
            const status = await sendMessage({ action: 'getStatus' });
            await loadData(status);
        }
    } catch (error) {
        console.error('Login error:', error);
        alert('Login failed. Please try again.');
    }
}

/**
 * Handle Save action (save to starred stories)
 */
async function handleSave() {
    try {
        const [tab] = await extApi.tabs.query({ active: true, currentWindow: true });
        if (tab) {
            // Open NewsBlur save popup
            const saveUrl = `${currentServerUrl}/api/add_url?url=${encodeURIComponent(tab.url)}`;
            extApi.tabs.create({ url: saveUrl });
        }
    } catch (error) {
        console.error('Save error:', error);
    }
}

/**
 * Handle Share action
 */
async function handleShare() {
    try {
        const [tab] = await extApi.tabs.query({ active: true, currentWindow: true });
        if (tab) {
            // Open NewsBlur share popup
            const shareUrl = `${currentServerUrl}/api/share_story?url=${encodeURIComponent(tab.url)}`;
            extApi.tabs.create({ url: shareUrl });
        }
    } catch (error) {
        console.error('Share error:', error);
    }
}

/**
 * Handle Subscribe action
 */
async function handleSubscribe() {
    try {
        const [tab] = await extApi.tabs.query({ active: true, currentWindow: true });
        if (tab) {
            // Open NewsBlur add feed page
            const addUrl = `${currentServerUrl}/add?url=${encodeURIComponent(tab.url)}`;
            extApi.tabs.create({ url: addUrl });
        }
    } catch (error) {
        console.error('Subscribe error:', error);
    }
}

// Initialize popup
console.log('NewsBlur Archive: Adding DOMContentLoaded listener');
document.addEventListener('DOMContentLoaded', init);
console.log('NewsBlur Archive: Script fully loaded');
