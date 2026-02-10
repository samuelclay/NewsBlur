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

// Track active page visits (also persisted to storage for service worker recovery)
const pageVisits = new Map(); // tabId -> { url, startTime, title, faviconUrl, domain, initialArchived, activeSeconds }

// Track archive timers
const archiveTimers = new Map(); // tabId -> timeoutId

// Sync state
let syncTimeout = null;
let isSyncing = false;

// Connected popup ports for real-time updates
const popupPorts = new Set();

/**
 * Persist page visits to storage for service worker recovery
 */
async function persistPageVisits() {
    const visits = Object.fromEntries(pageVisits);
    await storage.set('activePageVisits', visits);
}

/**
 * Recover page visits from storage after service worker restart
 */
async function recoverPageVisits() {
    const visits = await storage.get('activePageVisits', {});
    const now = Date.now();

    for (const [tabIdStr, visit] of Object.entries(visits)) {
        const tabId = parseInt(tabIdStr, 10);
        const elapsedTime = Math.round((now - visit.startTime) / 1000);

        // If enough time has passed and not yet archived, archive it
        // Use stored activeSeconds (not wall-clock time) for the reading time
        if (!visit.initialArchived && elapsedTime >= TIME_THRESHOLDS.MIN_TIME_ON_PAGE / 1000) {
            console.log('NewsBlur Archive: Recovering unarchived visit:', visit.url, (visit.activeSeconds || 0) + 's active');
            visit.initialArchived = true;
            await archivePage(visit, visit.activeSeconds || 0);
        }

        // Re-add to memory if the tab might still be open
        pageVisits.set(tabId, visit);
    }

    await persistPageVisits();
}

/**
 * Initialize the extension
 */
async function initialize() {
    console.log('NewsBlur Archive: Initializing...');

    // Initialize API client
    const isAuthenticated = await api.init();
    console.log('NewsBlur Archive: Authenticated:', isAuthenticated);

    // Recover any page visits that were tracked before service worker restart
    await recoverPageVisits();

    // Set up alarms for periodic sync
    const extApi = getExtensionAPI();
    extApi.alarms.create('periodicSync', { periodInMinutes: 5 });

    // Set up port listener for popup connections
    setupPopupPortListener();

    console.log('NewsBlur Archive: Initialized');
}

/**
 * Set up listener for popup port connections
 * Allows real-time updates to be sent to connected popups
 */
function setupPopupPortListener() {
    const extApi = getExtensionAPI();

    extApi.runtime.onConnect.addListener((port) => {
        if (port.name === 'popup') {
            console.log('NewsBlur Archive: Popup connected');
            popupPorts.add(port);

            port.onDisconnect.addListener(() => {
                console.log('NewsBlur Archive: Popup disconnected');
                popupPorts.delete(port);
            });
        }
    });
}

/**
 * Notify all connected popups about an event
 */
function notifyPopups(event, data) {
    popupPorts.forEach(port => {
        try {
            port.postMessage({ type: event, data });
        } catch (e) {
            // Port may have been closed
            popupPorts.delete(port);
        }
    });
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

    // Clear any existing timer for this tab
    if (archiveTimers.has(tabId)) {
        clearTimeout(archiveTimers.get(tabId));
        archiveTimers.delete(tabId);
    }

    // Record visit start
    const normalizedUrl = normalizeUrl(tab.url);
    const visit = {
        url: normalizedUrl,
        originalUrl: tab.url,
        startTime: Date.now(),
        title: tab.title || '',
        faviconUrl: tab.favIconUrl || '',
        domain: extractDomain(tab.url),
        initialArchived: false,
        activeSeconds: 0
    };
    pageVisits.set(tabId, visit);

    // Persist to storage for service worker recovery
    await persistPageVisits();

    console.log('NewsBlur Archive: Started tracking:', normalizedUrl);

    // Set timer for initial archive after MIN_TIME_ON_PAGE
    // Sends timeOnPage=0 because this just registers the URL/content.
    // The real active reading time is sent on tab close or navigation.
    const timerId = setTimeout(async () => {
        const currentVisit = pageVisits.get(tabId);
        if (currentVisit && currentVisit.url === normalizedUrl && !currentVisit.initialArchived) {
            console.log('NewsBlur Archive: Initial archive after', TIME_THRESHOLDS.MIN_TIME_ON_PAGE / 1000, 'seconds:', normalizedUrl);
            currentVisit.initialArchived = true;
            await persistPageVisits();
            await archivePage(currentVisit, 0);
        }
        archiveTimers.delete(tabId);
    }, TIME_THRESHOLDS.MIN_TIME_ON_PAGE);

    archiveTimers.set(tabId, timerId);
}

/**
 * Handle tab removal (tab closed)
 */
async function handleTabRemoved(tabId) {
    // Clear any pending archive timer
    if (archiveTimers.has(tabId)) {
        clearTimeout(archiveTimers.get(tabId));
        archiveTimers.delete(tabId);
    }

    const visit = pageVisits.get(tabId);
    if (!visit) return;

    pageVisits.delete(tabId);
    await persistPageVisits();

    // Use active reading time (last heartbeat value from content script).
    // We can't query the content script here because the tab is already closing.
    const activeTime = visit.activeSeconds || 0;
    const elapsedTime = Math.round((Date.now() - visit.startTime) / 1000);

    // If already archived, send update with final active time
    if (visit.initialArchived) {
        console.log('NewsBlur Archive: Final update on close:', visit.url, activeTime + 's active (' + elapsedTime + 's elapsed)');
        await archivePage(visit, activeTime);
        return;
    }

    // Skip if not enough elapsed time on page (never got initial archive)
    if (elapsedTime < TIME_THRESHOLDS.MIN_TIME_ON_PAGE / 1000) {
        console.log('NewsBlur Archive: Skipped (too short):', visit.url, elapsedTime + 's');
        return;
    }

    // Archive now (edge case: timer didn't fire but enough time passed)
    await archivePage(visit, activeTime);
}

/**
 * Handle navigation (leaving current page)
 */
async function handleBeforeNavigate(details) {
    // Only handle main frame
    if (details.frameId !== 0) return;

    const visit = pageVisits.get(details.tabId);
    if (!visit || visit.url === normalizeUrl(details.url)) return;

    // Clear any pending archive timer
    if (archiveTimers.has(details.tabId)) {
        clearTimeout(archiveTimers.get(details.tabId));
        archiveTimers.delete(details.tabId);
    }

    // Try to get final active time from content script before navigation completes
    try {
        const extApi = getExtensionAPI();
        const response = await extApi.tabs.sendMessage(details.tabId, { action: 'getActiveTime' });
        if (response && typeof response.activeSeconds === 'number') {
            visit.activeSeconds = response.activeSeconds;
        }
    } catch (e) {
        // Content script may already be unloaded, use last heartbeat value
    }

    pageVisits.delete(details.tabId);
    await persistPageVisits();

    const activeTime = visit.activeSeconds || 0;
    const elapsedTime = Math.round((Date.now() - visit.startTime) / 1000);

    // If already archived, send update with final active time
    if (visit.initialArchived) {
        console.log('NewsBlur Archive: Final update on navigate:', visit.url, activeTime + 's active (' + elapsedTime + 's elapsed)');
        await archivePage(visit, activeTime);
        return;
    }

    // Skip if not enough elapsed time on page (never got initial archive)
    if (elapsedTime < TIME_THRESHOLDS.MIN_TIME_ON_PAGE / 1000) {
        console.log('NewsBlur Archive: Skipped (too short):', visit.url, elapsedTime + 's');
        return;
    }

    // Archive now (edge case: timer didn't fire but enough time passed)
    await archivePage(visit, activeTime);
}

/**
 * Archive a page visit
 */
async function archivePage(visit, timeOnPage) {
    console.log('NewsBlur Archive: Archiving:', visit.url, timeOnPage + 's');

    // Try to extract content from the page
    let content = '';
    let contentLength = 0;
    let author = '';

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
                author = response.author || '';
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
        author: author,
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

            // Notify connected popups about new archives
            const successfulArchives = response.results ?
                response.results.filter(r => r.archive_id && !r.error) : [];
            if (successfulArchives.length > 0) {
                notifyPopups('archive:new', {
                    archives: successfulArchives,
                    count: successfulArchives.length
                });
            }
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
 * Handle OAuth callback - clean up OAuth state after authentication
 * Token exchange is now handled by the callback page itself
 */
async function handleOAuthCallback(details) {
    // Only handle main frame
    if (details.frameId !== 0) return;

    // Get the stored callback URL
    const data = await storage.get(['oauthCallbackUrl', 'authTabId']);
    if (!data.oauthCallbackUrl) return;

    // Check if this URL matches our OAuth callback
    if (!details.url.startsWith(data.oauthCallbackUrl)) return;

    console.log('NewsBlur Archive: OAuth callback page loaded');

    // Clear OAuth state (token exchange is handled by the page)
    await storage.remove(['oauthCallbackUrl', 'oauthServerUrl', 'authTabId']);
}

/**
 * Handle messages from popup or content scripts
 */
async function handleMessage(message, sender, sendResponse) {
    console.log('NewsBlur Archive: Message received:', message.action);

    switch (message.action) {
        case 'updateActiveTime':
            // Heartbeat from content script with active reading time
            if (sender.tab) {
                const visit = pageVisits.get(sender.tab.id);
                if (visit) {
                    visit.activeSeconds = message.activeSeconds;
                    await persistPageVisits();
                }
            }
            sendResponse({ success: true });
            break;

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
            await api.setToken(message.token, message.refreshToken, message.expiresIn);
            // Reinitialize API to pick up token and server URL
            await api.init();
            console.log('NewsBlur Archive: Token set, authenticated:', api.isAuthenticated());
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

        case 'serverChanged':
            // Reinitialize API with new server URL
            console.log('NewsBlur Archive: Server changed, reinitializing API...');
            await api.init();
            sendResponse({ success: true });
            break;

        case 'syncNow':
            // Force sync pending archives
            try {
                await syncPendingArchives();
                sendResponse({ success: true });
            } catch (error) {
                sendResponse({ success: false, error: error.message });
            }
            break;

        case 'settingsChanged':
            // Settings were changed in options page
            console.log('NewsBlur Archive: Settings changed');
            sendResponse({ success: true });
            break;

        case 'blocklistChanged':
            // Blocklist was changed in options page
            console.log('NewsBlur Archive: Blocklist changed');
            sendResponse({ success: true });
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
extApi.webNavigation.onCompleted.addListener(handleOAuthCallback); // OAuth callback interception
extApi.alarms.onAlarm.addListener(handleAlarm);
extApi.runtime.onMessage.addListener(handleMessage);

// Initialize on install
extApi.runtime.onInstalled.addListener(() => {
    console.log('NewsBlur Archive: Extension installed');
    initialize();
});

// Initialize on startup
initialize();
