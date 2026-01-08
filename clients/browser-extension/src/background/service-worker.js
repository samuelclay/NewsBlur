// NewsBlur Archive Extension - Background Service Worker

import { api } from '../lib/api.js';
import { storage } from '../lib/storage.js';
import {
    TIME_THRESHOLDS,
    BATCH_CONFIG
} from '../shared/constants.js';
import {
    shouldIgnoreUrl,
    isBlocked,
    normalizeUrl,
    extractDomain,
    getExtensionVersion,
    getBrowser,
    getExtensionAPI
} from '../shared/utils.js';

// Track active page visits
const pageVisits = new Map(); // tabId -> { url, startTime, title, faviconUrl }

// Sync state
let syncTimeout = null;
let isSyncing = false;

/**
 * Initialize the extension
 */
async function initialize() {
    console.log('NewsBlur Archive: Initializing...');

    // Initialize API client
    const isAuthenticated = await api.init();
    console.log('NewsBlur Archive: Authenticated:', isAuthenticated);

    // Set up alarms for periodic sync
    const extApi = getExtensionAPI();
    extApi.alarms.create('periodicSync', { periodInMinutes: 5 });

    console.log('NewsBlur Archive: Initialized');
}

/**
 * Handle tab updates (page load completed)
 */
async function handleTabUpdated(tabId, changeInfo, tab) {
    if (changeInfo.status !== 'complete' || !tab.url) {
        return;
    }

    // Skip ignored URLs
    if (shouldIgnoreUrl(tab.url)) {
        return;
    }

    // Skip incognito tabs
    if (tab.incognito) {
        return;
    }

    // Get user blocklist
    const userBlocklist = await storage.getUserBlocklist();

    // Check blocklist
    if (isBlocked(tab.url, userBlocklist)) {
        console.log('NewsBlur Archive: Blocked URL:', tab.url);
        return;
    }

    // Check if extension is enabled
    const settings = await storage.getSettings();
    if (!settings.enabled) {
        return;
    }

    // Record visit start
    const normalizedUrl = normalizeUrl(tab.url);
    pageVisits.set(tabId, {
        url: normalizedUrl,
        originalUrl: tab.url,
        startTime: Date.now(),
        title: tab.title || '',
        faviconUrl: tab.favIconUrl || '',
        domain: extractDomain(tab.url)
    });

    console.log('NewsBlur Archive: Started tracking:', normalizedUrl);
}

/**
 * Handle tab removal (tab closed)
 */
async function handleTabRemoved(tabId) {
    const visit = pageVisits.get(tabId);
    if (!visit) return;

    pageVisits.delete(tabId);

    const timeOnPage = Math.round((Date.now() - visit.startTime) / 1000);

    // Skip if not enough time on page
    if (timeOnPage < TIME_THRESHOLDS.MIN_TIME_ON_PAGE / 1000) {
        console.log('NewsBlur Archive: Skipped (too short):', visit.url, timeOnPage + 's');
        return;
    }

    await archivePage(visit, timeOnPage);
}

/**
 * Handle navigation (leaving current page)
 */
async function handleBeforeNavigate(details) {
    // Only handle main frame
    if (details.frameId !== 0) return;

    const visit = pageVisits.get(details.tabId);
    if (!visit || visit.url === normalizeUrl(details.url)) return;

    pageVisits.delete(details.tabId);

    const timeOnPage = Math.round((Date.now() - visit.startTime) / 1000);

    // Skip if not enough time on page
    if (timeOnPage < TIME_THRESHOLDS.MIN_TIME_ON_PAGE / 1000) {
        console.log('NewsBlur Archive: Skipped (too short):', visit.url, timeOnPage + 's');
        return;
    }

    await archivePage(visit, timeOnPage);
}

/**
 * Archive a page visit
 */
async function archivePage(visit, timeOnPage) {
    console.log('NewsBlur Archive: Archiving:', visit.url, timeOnPage + 's');

    // Try to extract content from the page
    let content = '';
    let contentLength = 0;

    try {
        const extApi = getExtensionAPI();
        // Find the tab that had this URL
        const tabs = await extApi.tabs.query({ url: visit.originalUrl });
        if (tabs.length > 0) {
            const response = await extApi.tabs.sendMessage(tabs[0].id, {
                action: 'extractContent'
            });
            if (response) {
                content = response.content || '';
                contentLength = response.contentLength || content.length;
            }
        }
    } catch (error) {
        console.log('NewsBlur Archive: Content extraction failed:', error.message);
    }

    const archive = {
        url: visit.url,
        title: visit.title,
        content: content,
        contentLength: contentLength,
        faviconUrl: visit.faviconUrl,
        domain: visit.domain,
        timeOnPage: timeOnPage,
        browser: getBrowser(),
        extensionVersion: getExtensionVersion(),
        archivedAt: Date.now()
    };

    // Add to pending queue
    await storage.addPendingArchive(archive);

    // Schedule sync
    scheduleSyncDebounced();
}

/**
 * Schedule a debounced sync
 */
function scheduleSyncDebounced() {
    if (syncTimeout) {
        clearTimeout(syncTimeout);
    }

    syncTimeout = setTimeout(() => {
        syncPendingArchives();
    }, TIME_THRESHOLDS.SYNC_DEBOUNCE);
}

/**
 * Sync pending archives to the server
 */
async function syncPendingArchives() {
    if (isSyncing) {
        console.log('NewsBlur Archive: Sync already in progress');
        return;
    }

    // Check if authenticated
    if (!api.isAuthenticated()) {
        console.log('NewsBlur Archive: Not authenticated, skipping sync');
        return;
    }

    // Check if sync is enabled
    const settings = await storage.getSettings();
    if (!settings.syncEnabled) {
        return;
    }

    isSyncing = true;

    try {
        const archives = await storage.popPendingArchives(BATCH_CONFIG.MAX_BATCH_SIZE);

        if (archives.length === 0) {
            console.log('NewsBlur Archive: Nothing to sync');
            return;
        }

        console.log('NewsBlur Archive: Syncing', archives.length, 'archives...');

        const response = await api.batchIngest(archives);

        if (response.code === 0) {
            console.log('NewsBlur Archive: Sync successful');
            await storage.setLastSync();
        } else {
            console.error('NewsBlur Archive: Sync failed:', response.message);
            // Return archives to queue
            await storage.returnPendingArchives(archives);
        }
    } catch (error) {
        console.error('NewsBlur Archive: Sync error:', error);
        // Archives already popped will be lost on error - that's acceptable for now
    } finally {
        isSyncing = false;
    }

    // Check if more archives are pending
    const remaining = await storage.getPendingArchives();
    if (remaining.length > 0) {
        console.log('NewsBlur Archive:', remaining.length, 'archives still pending');
        scheduleSyncDebounced();
    }
}

/**
 * Handle alarm events
 */
function handleAlarm(alarm) {
    if (alarm.name === 'periodicSync') {
        syncPendingArchives();
    }
}

/**
 * Handle messages from popup or content scripts
 */
async function handleMessage(message, sender, sendResponse) {
    console.log('NewsBlur Archive: Message received:', message.action);

    switch (message.action) {
        case 'getStatus':
            sendResponse({
                authenticated: api.isAuthenticated(),
                pendingCount: (await storage.getPendingArchives()).length,
                lastSync: await storage.getLastSync()
            });
            break;

        case 'login':
            // OAuth login will be handled by popup
            sendResponse({ success: true });
            break;

        case 'logout':
            await api.clearToken();
            sendResponse({ success: true });
            break;

        case 'setToken':
            await api.setToken(message.token);
            sendResponse({ success: true });
            break;

        case 'sync':
            syncPendingArchives();
            sendResponse({ success: true });
            break;

        case 'getArchives':
            try {
                const response = await api.listArchives(message.params || {});
                sendResponse(response);
            } catch (error) {
                sendResponse({ error: error.message });
            }
            break;

        case 'getCategories':
            try {
                const response = await api.getCategories();
                sendResponse(response);
            } catch (error) {
                sendResponse({ error: error.message });
            }
            break;

        case 'getStats':
            try {
                const response = await api.getStats();
                sendResponse(response);
            } catch (error) {
                sendResponse({ error: error.message });
            }
            break;

        case 'getSettings':
            sendResponse(await storage.getSettings());
            break;

        case 'updateSettings':
            await storage.updateSettings(message.settings);
            sendResponse({ success: true });
            break;

        case 'getBlocklist':
            sendResponse(await storage.getUserBlocklist());
            break;

        case 'addToBlocklist':
            await storage.addToBlocklist(message.domain);
            sendResponse({ success: true });
            break;

        case 'removeFromBlocklist':
            await storage.removeFromBlocklist(message.domain);
            sendResponse({ success: true });
            break;

        case 'archiveCurrentPage':
            // Force archive the current page
            const tab = sender.tab;
            if (tab) {
                const visit = {
                    url: normalizeUrl(tab.url),
                    originalUrl: tab.url,
                    title: tab.title || '',
                    faviconUrl: tab.favIconUrl || '',
                    domain: extractDomain(tab.url)
                };
                await archivePage(visit, 0);
                sendResponse({ success: true });
            }
            break;

        default:
            sendResponse({ error: 'Unknown action' });
    }

    return true; // Keep the message channel open for async response
}

// Set up event listeners
const extApi = getExtensionAPI();

extApi.tabs.onUpdated.addListener(handleTabUpdated);
extApi.tabs.onRemoved.addListener(handleTabRemoved);
extApi.webNavigation.onBeforeNavigate.addListener(handleBeforeNavigate);
extApi.alarms.onAlarm.addListener(handleAlarm);
extApi.runtime.onMessage.addListener(handleMessage);

// Initialize on install
extApi.runtime.onInstalled.addListener(() => {
    console.log('NewsBlur Archive: Extension installed');
    initialize();
});

// Initialize on startup
initialize();
