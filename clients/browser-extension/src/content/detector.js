// NewsBlur Archive Extension - Content Script
// Handles content extraction and active reading time tracking

// --- Active Time Tracker ---
// Tracks how long the user is actively reading (visible tab + not idle)

const IDLE_TIMEOUT = 60000;          // 60 seconds of no activity = idle
const HEARTBEAT_INTERVAL = 10000;    // Report active time every 10 seconds

let activeSeconds = 0;
let lastActivityTime = Date.now();
let lastHeartbeatActiveSeconds = 0;

function isUserActive() {
    return (Date.now() - lastActivityTime) < IDLE_TIMEOUT;
}

function onUserActivity() {
    lastActivityTime = Date.now();
}

// Listen for user activity signals
const activityEvents = ['mousemove', 'scroll', 'keydown', 'click', 'touchstart'];
for (const event of activityEvents) {
    document.addEventListener(event, onUserActivity, { passive: true });
}

// Listen for visibility changes
document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') {
        // Reset activity timer when tab becomes visible (user switched to this tab)
        lastActivityTime = Date.now();
    }
});

// Accumulate active seconds every 1 second
setInterval(() => {
    if (document.visibilityState === 'visible' && isUserActive()) {
        activeSeconds++;
    }
}, 1000);

// Send heartbeat to service worker every HEARTBEAT_INTERVAL
setInterval(() => {
    // Only send if active time has changed since last heartbeat
    if (activeSeconds === lastHeartbeatActiveSeconds) return;
    lastHeartbeatActiveSeconds = activeSeconds;

    try {
        chrome.runtime.sendMessage({
            action: 'updateActiveTime',
            activeSeconds: activeSeconds
        }, () => {
            // Ignore errors (tab may not be tracked by service worker)
            if (chrome.runtime.lastError) { /* expected */ }
        });
    } catch (e) {
        // Service worker not available, ignore
    }
}, HEARTBEAT_INTERVAL);

// --- End Active Time Tracker ---

/**
 * Simple content extractor (inspired by Readability)
 * Extracts the main text content from a page
 */
function extractContent() {
    // Clone document to avoid modifying the original
    const documentClone = document.cloneNode(true);

    // Remove unwanted elements
    const unwantedSelectors = [
        'script', 'style', 'noscript', 'iframe', 'object', 'embed',
        'nav', 'header', 'footer', 'aside', 'form',
        '[role="navigation"]', '[role="banner"]', '[role="contentinfo"]',
        '.sidebar', '.nav', '.navigation', '.menu', '.header', '.footer',
        '.ad', '.ads', '.advertisement', '.sponsored',
        '.social', '.share', '.sharing', '.social-share',
        '.comments', '.comment-section', '#comments',
        '.related', '.recommended', '.popular',
        '.newsletter', '.subscribe', '.subscription'
    ];

    for (const selector of unwantedSelectors) {
        const elements = documentClone.querySelectorAll(selector);
        elements.forEach(el => el.remove());
    }

    // Try to find main content area
    const contentSelectors = [
        'article',
        '[role="main"]',
        'main',
        '.post-content',
        '.article-content',
        '.entry-content',
        '.content',
        '#content',
        '.post',
        '.article',
        '.story'
    ];

    let contentElement = null;

    for (const selector of contentSelectors) {
        const element = documentClone.querySelector(selector);
        if (element && element.textContent.trim().length > 200) {
            contentElement = element;
            break;
        }
    }

    // Fall back to body if no content area found
    if (!contentElement) {
        contentElement = documentClone.body;
    }

    // Extract text content
    let textContent = '';

    if (contentElement) {
        // Get all text nodes
        const walker = document.createTreeWalker(
            contentElement,
            NodeFilter.SHOW_TEXT,
            null,
            false
        );

        const textParts = [];
        let node;
        while ((node = walker.nextNode())) {
            const text = node.textContent.trim();
            if (text.length > 0) {
                // Check if parent is a block element
                const parent = node.parentElement;
                const isBlock = parent && window.getComputedStyle(parent).display === 'block';

                if (isBlock && textParts.length > 0) {
                    textParts.push('\n\n');
                }
                textParts.push(text);
            }
        }

        textContent = textParts.join(' ')
            .replace(/\s+/g, ' ')
            .replace(/\n\s+\n/g, '\n\n')
            .trim();
    }

    // Get metadata
    const title = document.title || '';
    const description = document.querySelector('meta[name="description"]')?.content || '';
    const ogTitle = document.querySelector('meta[property="og:title"]')?.content || '';
    const ogDescription = document.querySelector('meta[property="og:description"]')?.content || '';

    // Extract author from multiple sources (in priority order)
    const author =
        document.querySelector('meta[name="author"]')?.content ||
        document.querySelector('meta[property="article:author"]')?.content ||
        document.querySelector('meta[name="dc.creator"]')?.content ||
        document.querySelector('[rel="author"]')?.textContent?.trim() ||
        document.querySelector('.byline')?.textContent?.trim() ||
        document.querySelector('.author')?.textContent?.trim() ||
        '';

    // Use best available title and description
    const bestTitle = ogTitle || title;
    const bestDescription = ogDescription || description;

    return {
        title: bestTitle,
        content: textContent,
        contentLength: textContent.length,
        excerpt: bestDescription || textContent.substring(0, 300),
        author: author
    };
}

/**
 * Get page metadata
 */
function getPageMetadata() {
    return {
        url: window.location.href,
        title: document.title,
        description: document.querySelector('meta[name="description"]')?.content || '',
        ogTitle: document.querySelector('meta[property="og:title"]')?.content || '',
        ogDescription: document.querySelector('meta[property="og:description"]')?.content || '',
        ogImage: document.querySelector('meta[property="og:image"]')?.content || '',
        canonicalUrl: document.querySelector('link[rel="canonical"]')?.href || '',
        author: document.querySelector('meta[name="author"]')?.content || '',
        publishedTime: document.querySelector('meta[property="article:published_time"]')?.content || ''
    };
}

// Listen for messages from the background script
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.action === 'extractContent') {
        try {
            const result = extractContent();
            sendResponse(result);
        } catch (error) {
            console.error('NewsBlur Archive: Content extraction error:', error);
            sendResponse({
                title: document.title,
                content: '',
                contentLength: 0,
                error: error.message
            });
        }
    } else if (request.action === 'getActiveTime') {
        sendResponse({ activeSeconds: activeSeconds });
    } else if (request.action === 'getMetadata') {
        try {
            const result = getPageMetadata();
            sendResponse(result);
        } catch (error) {
            console.error('NewsBlur Archive: Metadata extraction error:', error);
            sendResponse({ error: error.message });
        }
    }
    return true; // Keep message channel open for async response
});

// Listen for OAuth token messages from the callback page
window.addEventListener('message', async (event) => {
    // Only accept messages from the same frame
    if (event.source !== window) return;

    // Check if this is our OAuth token message
    if (event.data && event.data.type === 'NEWSBLUR_ARCHIVE_TOKEN') {
        console.log('NewsBlur Archive: Received token from callback page');

        const tokenData = {
            authToken: event.data.accessToken,
            refreshToken: event.data.refreshToken || null,
            tokenExpiry: event.data.expiresIn ? Date.now() + (event.data.expiresIn * 1000) : null
        };

        // Save directly to storage as primary method (more reliable across browsers)
        try {
            await chrome.storage.local.set(tokenData);
            console.log('NewsBlur Archive: Token saved to storage');
        } catch (storageError) {
            console.error('NewsBlur Archive: Storage save failed:', storageError);
        }

        // Also notify service worker to reinitialize (fire and forget)
        try {
            chrome.runtime.sendMessage({
                action: 'setToken',
                token: event.data.accessToken,
                refreshToken: event.data.refreshToken,
                expiresIn: event.data.expiresIn
            }, (response) => {
                // Check for runtime errors (common in Firefox)
                if (chrome.runtime.lastError) {
                    console.log('NewsBlur Archive: Service worker notification failed (token already saved to storage):',
                        chrome.runtime.lastError.message);
                    return;
                }
                if (response && response.success) {
                    console.log('NewsBlur Archive: Service worker notified');
                }
            });
        } catch (msgError) {
            // This is OK - token is already saved to storage
            console.log('NewsBlur Archive: Service worker notification error (token already saved):', msgError.message);
        }
    }
});

// Log that the content script is loaded
console.log('NewsBlur Archive: Content script loaded');
