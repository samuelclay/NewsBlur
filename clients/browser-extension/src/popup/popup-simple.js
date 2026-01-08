// NewsBlur Archive Extension - Simple Popup Script (no modules)

console.log('NewsBlur Archive: Simple popup script loaded');

// Default server URL
var DEFAULT_SERVER_URL = 'https://newsblur.com';
var currentServerUrl = DEFAULT_SERVER_URL;

// Load server URL from storage
async function loadServerUrl() {
    return new Promise(function(resolve) {
        chrome.storage.local.get(['useCustomServer', 'serverUrl'], function(result) {
            if (result.useCustomServer && result.serverUrl) {
                currentServerUrl = result.serverUrl;
            } else {
                currentServerUrl = DEFAULT_SERVER_URL;
            }
            console.log('NewsBlur Archive: Using server:', currentServerUrl);
            resolve(currentServerUrl);
        });
    });
}

// Update server display in footer
function updateServerDisplay() {
    var serverName = document.getElementById('serverName');
    var serverBadge = document.getElementById('serverBadge');

    if (serverName) {
        try {
            var url = new URL(currentServerUrl);
            serverName.textContent = url.host;
        } catch (e) {
            serverName.textContent = currentServerUrl;
        }
    }

    if (serverBadge) {
        chrome.storage.local.get(['useCustomServer'], function(result) {
            if (result.useCustomServer) {
                serverBadge.classList.add('custom');
                serverBadge.title = 'Connected to custom server';
            } else {
                serverBadge.classList.remove('custom');
                serverBadge.title = 'Connected to NewsBlur';
            }
        });
    }
}

document.addEventListener('DOMContentLoaded', async function() {
    console.log('NewsBlur Archive: DOM ready');

    // Load server URL first
    await loadServerUrl();
    updateServerDisplay();

    // Settings button
    var settingsButton = document.querySelector('.settings-button');
    console.log('NewsBlur Archive: Settings button:', settingsButton);

    if (settingsButton) {
        settingsButton.addEventListener('click', function() {
            console.log('NewsBlur Archive: Settings clicked');
            chrome.runtime.openOptionsPage();
        });
    }

    // Footer links - use dynamic server URL
    var openArchiveLink = document.getElementById('openArchiveLink');
    var aboutLink = document.getElementById('aboutLink');
    var searchArchivesLink = document.getElementById('searchArchivesLink');

    if (openArchiveLink) {
        openArchiveLink.addEventListener('click', function(e) {
            e.preventDefault();
            chrome.tabs.create({ url: currentServerUrl + '/archive' });
        });
    }

    if (aboutLink) {
        aboutLink.addEventListener('click', function(e) {
            e.preventDefault();
            chrome.tabs.create({ url: currentServerUrl + '/about' });
        });
    }

    if (searchArchivesLink) {
        searchArchivesLink.addEventListener('click', function(e) {
            e.preventDefault();
            chrome.tabs.create({ url: currentServerUrl + '/archive' });
        });
    }

    // Check authentication status
    chrome.storage.local.get(['authToken'], function(result) {
        var loginSection = document.getElementById('loginSection');
        var mainSection = document.getElementById('mainSection');

        if (result.authToken) {
            // Authenticated - show main section
            if (loginSection) loginSection.classList.add('hidden');
            if (mainSection) mainSection.classList.remove('hidden');
            loadMainContent();
        } else {
            // Not authenticated - show login section
            if (loginSection) loginSection.classList.remove('hidden');
            if (mainSection) mainSection.classList.add('hidden');
        }
    });

    // Login button - opens OAuth page in new tab
    var loginButton = document.getElementById('loginButton');
    if (loginButton) {
        loginButton.addEventListener('click', function() {
            console.log('NewsBlur Archive: Login clicked, server:', currentServerUrl);

            // Use a web-based callback URL that the extension intercepts via webNavigation
            var callbackUrl = currentServerUrl + '/oauth/extension-callback/';
            console.log('NewsBlur Archive: Callback URL:', callbackUrl);

            var authUrl = currentServerUrl + '/oauth/authorize/' +
                '?client_id=newsblur-archive-extension' +
                '&redirect_uri=' + encodeURIComponent(callbackUrl) +
                '&response_type=code' +
                '&scope=read';

            console.log('NewsBlur Archive: Auth URL:', authUrl);

            // Store the callback URL pattern for the service worker to intercept
            chrome.storage.local.set({
                oauthCallbackUrl: callbackUrl,
                oauthServerUrl: currentServerUrl
            });

            // Open OAuth page in new tab
            chrome.tabs.create({ url: authUrl }, function(tab) {
                console.log('NewsBlur Archive: Opened auth tab:', tab.id);
                // Store the tab ID so we can track and close it
                chrome.storage.local.set({ authTabId: tab.id });
            });
        });
    }

    // Action buttons
    var saveButton = document.getElementById('saveButton');
    var shareButton = document.getElementById('shareButton');
    var subscribeButton = document.getElementById('subscribeButton');

    if (saveButton) {
        saveButton.addEventListener('click', function() {
            chrome.tabs.query({ active: true, currentWindow: true }, function(tabs) {
                if (tabs[0]) {
                    chrome.tabs.create({ url: currentServerUrl + '/api/add_url?url=' + encodeURIComponent(tabs[0].url) });
                }
            });
        });
    }

    if (shareButton) {
        shareButton.addEventListener('click', function() {
            chrome.tabs.query({ active: true, currentWindow: true }, function(tabs) {
                if (tabs[0]) {
                    chrome.tabs.create({ url: currentServerUrl + '/api/share_story?url=' + encodeURIComponent(tabs[0].url) });
                }
            });
        });
    }

    if (subscribeButton) {
        subscribeButton.addEventListener('click', function() {
            chrome.tabs.query({ active: true, currentWindow: true }, function(tabs) {
                if (tabs[0]) {
                    chrome.tabs.create({ url: currentServerUrl + '/add?url=' + encodeURIComponent(tabs[0].url) });
                }
            });
        });
    }

    console.log('NewsBlur Archive: Event listeners set up');
});

// Sync pending archives from popup (works around service worker SSL issues)
async function syncPendingArchives() {
    console.log('NewsBlur Archive: syncPendingArchives called, server:', currentServerUrl);

    var result = await chrome.storage.local.get(['pendingArchives', 'authToken']);
    var pending = result.pendingArchives || [];
    var token = result.authToken;

    console.log('NewsBlur Archive: Pending archives:', pending.length, 'Token:', token ? 'present' : 'missing');

    if (!token || pending.length === 0) {
        console.log('NewsBlur Archive: Nothing to sync or not authenticated');
        return;
    }

    console.log('NewsBlur Archive: Syncing', pending.length, 'archives from popup...');

    try {
        var response = await fetch(currentServerUrl + '/api/archive/batch_ingest', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'Authorization': 'Bearer ' + token
            },
            body: 'archives=' + encodeURIComponent(JSON.stringify(pending))
        });

        if (!response.ok) {
            throw new Error('HTTP ' + response.status);
        }

        var data = await response.json();
        if (data.code === 0) {
            console.log('NewsBlur Archive: Sync successful!');
            // Clear synced archives
            await chrome.storage.local.set({
                pendingArchives: [],
                lastSync: Date.now()
            });
            // Update UI
            var pendingCount = document.getElementById('pendingCount');
            if (pendingCount) pendingCount.textContent = '0';
            var lastSync = document.getElementById('lastSync');
            if (lastSync) lastSync.textContent = 'Just now';
        } else {
            console.error('NewsBlur Archive: Sync failed:', data.message);
        }
    } catch (error) {
        console.error('NewsBlur Archive: Sync error:', error);
    }
}

// Load main content when authenticated
function loadMainContent() {
    // Trigger sync when popup opens
    syncPendingArchives();

    // Update current tab info
    chrome.tabs.query({ active: true, currentWindow: true }, function(tabs) {
        if (tabs[0]) {
            var currentTitle = document.getElementById('currentTitle');
            var currentFavicon = document.getElementById('currentFavicon');

            if (currentTitle) {
                currentTitle.textContent = tabs[0].title ? tabs[0].title.substring(0, 50) : 'Current Page';
            }
            if (currentFavicon && tabs[0].favIconUrl) {
                currentFavicon.src = tabs[0].favIconUrl;
                currentFavicon.style.display = 'block';
            }
        }
    });

    // Load stats
    chrome.storage.local.get(['pendingArchives', 'lastSync'], function(result) {
        var pendingCount = document.getElementById('pendingCount');
        var lastSync = document.getElementById('lastSync');

        if (pendingCount) {
            var pending = result.pendingArchives || [];
            pendingCount.textContent = pending.length;
        }

        if (lastSync && result.lastSync) {
            var diff = Date.now() - result.lastSync;
            var minutes = Math.floor(diff / 60000);
            var hours = Math.floor(diff / 3600000);

            if (minutes < 1) {
                lastSync.textContent = 'Just now';
            } else if (minutes < 60) {
                lastSync.textContent = minutes + 'm ago';
            } else if (hours < 24) {
                lastSync.textContent = hours + 'h ago';
            } else {
                lastSync.textContent = Math.floor(hours / 24) + 'd ago';
            }
        }
    });

    // Load recent archives list
    var recentList = document.getElementById('recentList');
    if (recentList) {
        recentList.innerHTML = '<div class="empty-message">Browse the web to start building your archive.</div>';
    }
}
