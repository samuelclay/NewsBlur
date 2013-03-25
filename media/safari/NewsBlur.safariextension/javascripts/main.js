/* main.js
 * Adapted by Nick Peelman (nick@#peelman.us)
 *
 * Based on: NewsBlur Notifier by Espen Helgedagsrud (kleevah@zawiarr.com)
 *   (https://addons.opera.com/en/extensions/details/newsblur-notifier/)
 *   Based on Google Reader Notifier by al007 
 *    (http://addons.opera.com/extensions/details/google-reader-notifier/)
 */

var NEWSBLUR_DOMAIN   = "newsblur.com";
var NEWSBLUR_PATH     = "/folder/everything";
var GET_UNREAD_UPDATE = "/reader/refresh_feeds";
var API_LOGIN_PATH = "/api/login";

var TITLE_REGEX_SINGLE = /\((\d+)\)\sNewsBlur/g;
var TITLE_REGEX_DOUBLE = /\((\d+)\/(\d+)\)\sNewsBlur/g;
var TITLE_UPDATE_FREQ = 1000; // We check title every second

var ICON_OK       = "icons/icon-32.png";
var ICON_NO_AUTH 	= "icons/icon-32-disabled.png";

var COLOR_UNREAD  = "#D30004"; 
var COLOR_FOCUSED = "#6EA74A";

var initialRun = true;
var isAuthenticated = false;
var useSSL = true;
var updateTime;
var updateCountTimer, titleUpdateTimer;

var titleFailCount = 0;
var unreadFocused = 0; // Unread counters for focused (ps) and normal (nt).
var unreadNormal = 0;

function init() {
  var url = getURL();
  login();
  
  if (safari.extension.settings.updateTime && safari.extension.settings.updateTime > 0) {
    clearInterval(updateCountTimer);
    updateCountTimer = setInterval(getUpdateCount, safari.extension.settings.updateTime);    
  }
  getUpdateCount();
}

// Login
function login(){
  var req = new XMLHttpRequest();
  
  req.open("POST", getURL() + API_LOGIN_PATH, true);
  req.onreadystatechange = function() {
    if ((req.readyState == 4) && (req.status == 200)) {
      var resp = JSON.parse(req.responseText);
      if (resp) {
        // Auth check.
        if (resp['authenticated'] != true) {
          isAuthenticated = false;
          return;
        }
        
        // Change icon if auth is OK.
        if (isAuthenticated == false) {
          isAuthenticated = true;
          //safari.extension.toolbarItems[0].enabled = true;
        }
      }
    }
  }
  req.send("username=" + encodeURIComponent(safari.extension.secureSettings.username) + "&password=" + encodeURIComponent(safari.extension.secureSettings.username));
}

// Fetch the unread count from the NewsBlur API using JSON.
function getUpdateCount(){
  var req = new XMLHttpRequest();
  
  req.open("GET", getURL() + GET_UNREAD_UPDATE, true);
  req.onreadystatechange = function() {
    if ((req.readyState == 4) && (req.status == 200)) {
      var resp = JSON.parse(req.responseText);
      if (resp) {
        
        // Auth check.
        if (resp['authenticated'] != true) {
          isAuthenticated = false;
          return;
        }
        
        // Change icon if auth is OK.
        if (isAuthenticated == false) {
          isAuthenticated = true;
        }
        
        // Check for unread count in returned JSON.
        var ps = 0, nt = 0;
        for (var key in resp.feeds) { 
          if (resp.feeds.hasOwnProperty(key)){
            if (resp.feeds[key].ps) ps += resp.feeds[key].ps;
            if (resp.feeds[key].nt) nt += resp.feeds[key].nt;
          }
        }
        
        // Update button
        unreadFocused = ps;
        unreadNormal = nt;
        updateButton();
      }
    }
  }
  req.send(null);
}

// Returns the URL for NewsBlur with proper prefix.
function getURL(){
  var dprefix;
  dprefix  = (useSSL) ? "https://" : "http://";
  
  return dprefix + NEWSBLUR_DOMAIN;
}


// Update the button badge with current unread count.
function updateButton() {
  var focused = parseInt(unreadFocused);
  var normal = parseInt(unreadNormal)
  var total = focused + normal;
  var displayCount = 0;
  
  if (safari.extension.settings.countStyle == 'normal')
    displayCount = normal;
  else if (safari.extension.settings.countStyle == 'total')
    displayCount = total;
  else
    displayCount = focused;

  if (safari.extension.toolbarItems.count < 1)
    return;

  button = safari.extension.toolbarItems[0]

  if (button) {
    if (displayCount == 0) {
      button.badge = 0
    } else {
      var finalCount = (displayCount > 99) ? 99 : displayCount;
      button.badge =  finalCount; 
    }
  }
}

function isTabFocused() {
  try {
    var tab = safari.application.activeBrowserWindow.activeTab
    if (tab.url.indexOf(getURL()) != -1)
      return tab;
  } catch (e) { console.log(e); }
  return false;
}

function isTabOpen() {
  try {
    var currentWindow = safari.application.activeBrowserWindow
    for (var tab in currentWindow.tabs) {
      if (tab.url && tab.url.indexOf(getURL()) != -1) {
        console.log("tab open already");
        tab.activate();
        return tab;
      }
    }
  } catch (e) { console.log(e); }
  
  return false;
}

function settingChanged(event) {
  getUpdateCount();
}

function openNewsBlur(event) {
  if (event.target.identifier !== "menuOpenNewsBlur") return;
  if (event.command !== 'openNewsBlur') return;
  if (isTabFocused()) return;
  if (isTabOpen()) return;

	var tab = safari.application.activeBrowserWindow.openTab();
	tab.url = getURL() + NEWSBLUR_PATH;
}


var settingsListener = safari.extension.settings.addEventListener("change", settingChanged, false);
var openListener = safari.application.addEventListener("command", openNewsBlur, false);


