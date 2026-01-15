// NewsBlur Archive Extension - OAuth Callback Handler

console.log('NewsBlur Archive: OAuth callback loaded');

var statusDiv = document.getElementById('status');

function showError(message) {
    statusDiv.innerHTML = '<div class="error">' + message + '</div>' +
        '<p style="margin-top: 16px; color: #666;">You can close this tab and try again.</p>';
}

function showSuccess(message) {
    statusDiv.innerHTML = '<div class="success">' + message + '</div>' +
        '<p style="margin-top: 16px; color: #666;">This tab will close automatically...</p>';
}

// Parse the URL for authorization code or error
var urlParams = new URLSearchParams(window.location.search);
var code = urlParams.get('code');
var error = urlParams.get('error');
var errorDescription = urlParams.get('error_description');

console.log('NewsBlur Archive: URL params - code:', code, 'error:', error);

if (error) {
    showError('Authorization failed: ' + (errorDescription || error));
} else if (code) {
    // Exchange the code for a token
    chrome.storage.local.get(['useCustomServer', 'serverUrl'], function(result) {
        var serverUrl = 'https://newsblur.com';
        if (result.useCustomServer && result.serverUrl) {
            serverUrl = result.serverUrl;
        }
        console.log('NewsBlur Archive: Exchanging code for token on server:', serverUrl);

        var callbackUrl = chrome.runtime.getURL('src/popup/oauth-callback.html');

        fetch(serverUrl + '/oauth/token/', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: 'grant_type=authorization_code' +
                '&code=' + encodeURIComponent(code) +
                '&redirect_uri=' + encodeURIComponent(callbackUrl) +
                '&client_id=newsblur-archive-extension'
        })
        .then(function(response) {
            console.log('NewsBlur Archive: Token response status:', response.status);
            return response.json();
        })
        .then(function(data) {
            console.log('NewsBlur Archive: Token response:', data);
            if (data.access_token) {
                // Save the token
                chrome.storage.local.set({
                    authToken: data.access_token,
                    refreshToken: data.refresh_token || null,
                    tokenExpiry: data.expires_in ? Date.now() + (data.expires_in * 1000) : null
                }, function() {
                    console.log('NewsBlur Archive: Token saved successfully');
                    showSuccess('Authorization successful! You are now connected to NewsBlur.');

                    // Close this tab after a brief delay
                    setTimeout(function() {
                        window.close();
                    }, 1500);
                });
            } else {
                showError('Failed to get access token: ' + (data.error_description || data.error || 'Unknown error'));
            }
        })
        .catch(function(e) {
            console.error('NewsBlur Archive: Token exchange error:', e);
            showError('Failed to exchange authorization code: ' + e.message);
        });
    });
} else {
    showError('No authorization code received. Please try again.');
}
