// NewsBlur Archive Extension - Popup Script

import { DEFAULT_SERVER_URL, OAUTH_CONFIG, getOAuthAuthorizeUrl } from '../shared/constants.js';
import { formatRelativeTime, truncateText, getExtensionAPI } from '../shared/utils.js';
import { storage } from '../lib/storage.js';

console.log('NewsBlur Archive: Popup script loaded');

const extApi = getExtensionAPI();
console.log('NewsBlur Archive: Extension API:', extApi ? 'available' : 'NOT FOUND');

// Current server URL (loaded from storage)
let currentServerUrl = DEFAULT_SERVER_URL;

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
    } else {
        showLoginSection();
    }

    // Set up current tab info
    await loadCurrentTab();

    // Set up event listeners
    setupEventListeners();
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
