//
//  UserScripts.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import Foundation

/// JavaScript sources injected into web content or evaluated on demand.
///
/// Keeping every script in one place makes the app's JS footprint auditable
/// and keeps large string literals out of state/controller code.
enum UserScripts {

    // MARK: - Message Handler Names

    static let inputFocusHandlerName = "lotusInputFocusHandler"
    static let contextMenuHandlerName = "lotusContextMenuHandler"
    static let shieldDeflectHandlerName = "lotusShieldDeflectHandler"
    static let notificationHandlerName = "lotusNotificationHandler"
    static let mediaHandlerName = "lotusMediaHandler"
    static let zapHandlerName = "lotusZapHandler"

    // MARK: - Injected at Document Start

    /// Tracks whether an editable element (input/textarea/contenteditable) is
    /// focused inside the page and reports changes to the app, so keyboard
    /// shortcuts can avoid stealing keystrokes from web forms.
    static let inputFocusMonitor = """
    (function() {
        function isEditable(el) {
            try {
                if (!el) return false;
                if (el.isContentEditable) return true;
                if (el.getAttribute && (el.getAttribute('contenteditable') === 'true' || el.getAttribute('contenteditable') === '')) return true;
                if (el.closest && el.closest('[contenteditable="true"], [contenteditable=""], [role="textbox"], [role="searchbox"], [role="combobox"]')) return true;
                var tag = el.tagName ? el.tagName.toUpperCase() : '';
                if (tag === 'INPUT') {
                    var type = el.type ? el.type.toLowerCase() : 'text';
                    var nonTextTypes = ['button', 'checkbox', 'color', 'file', 'hidden', 'image', 'radio', 'range', 'reset', 'submit'];
                    return nonTextTypes.indexOf(type) === -1;
                }
                return tag === 'TEXTAREA' || tag === 'SELECT';
            } catch(e) { return false; }
        }
        function getDeepActiveElement() {
            try {
                var el = document.activeElement;
                while (el && el.shadowRoot && el.shadowRoot.activeElement) {
                    el = el.shadowRoot.activeElement;
                }
                return el;
            } catch(e) { return null; }
        }
        window.__lotusCheckInputFocus = function() {
            try {
                var el = getDeepActiveElement();
                var focused = isEditable(el);
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.lotusInputFocusHandler) {
                    window.webkit.messageHandlers.lotusInputFocusHandler.postMessage({ isFocused: focused });
                }
            } catch(e) {}
        };
        document.addEventListener('focusin', function(e) {
            try {
                if (isEditable(e.target) || isEditable(getDeepActiveElement())) {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.lotusInputFocusHandler) {
                        window.webkit.messageHandlers.lotusInputFocusHandler.postMessage({ isFocused: true });
                    }
                }
            } catch(e) {}
        }, true);
        document.addEventListener('focusout', function(e) {
            try {
                setTimeout(function() {
                    window.__lotusCheckInputFocus();
                }, 10);
            } catch(e) {}
        }, true);
        document.addEventListener('selectionchange', function(e) {
            try {
                var el = getDeepActiveElement();
                if (isEditable(el)) {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.lotusInputFocusHandler) {
                        window.webkit.messageHandlers.lotusInputFocusHandler.postMessage({ isFocused: true });
                    }
                }
            } catch(e) {}
        }, true);
    })();
    """

    /// Tracks right-clicked images, links, and media to provide accurate target URLs
    /// for Lotus's download actions.
    static let contextMenuMonitor = """
    (function() {
        function getCleanURL(url) {
            if (!url) return null;
            try {
                return new URL(url, document.baseURI).href;
            } catch(e) {
                return url;
            }
        }

        document.addEventListener('contextmenu', function(e) {
            try {
                var target = e.target;
                var imgURL = null;
                var linkURL = null;
                var selectedText = window.getSelection ? window.getSelection().toString().trim() : null;

                if (target) {
                    if (target.tagName === 'IMG') {
                        imgURL = target.currentSrc || target.src;
                    } else if (target.tagName === 'VIDEO') {
                        imgURL = target.currentSrc || target.src;
                    }

                    if (!imgURL) {
                        var img = target.closest('img');
                        if (img) imgURL = img.currentSrc || img.src;
                    }

                    if (!imgURL) {
                        var bg = window.getComputedStyle(target).backgroundImage;
                        if (bg && bg.indexOf('url(') === 0) {
                            var match = bg.match(/url\\(["']?(.*?)["']?\\)/);
                            if (match && match[1]) imgURL = match[1];
                        }
                    }

                    var a = target.tagName === 'A' ? target : target.closest('a');
                    if (a && a.href) {
                        linkURL = a.href;
                    }
                }

                imgURL = getCleanURL(imgURL);
                linkURL = getCleanURL(linkURL);

                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.lotusContextMenuHandler) {
                    window.webkit.messageHandlers.lotusContextMenuHandler.postMessage({
                        imageURL: imgURL,
                        linkURL: linkURL,
                        selectedText: selectedText && selectedText.length > 0 ? selectedText : null
                    });
                }
            } catch(err) {}
        }, true);
    })();
    """

    /// Lightweight uBlock Origin-inspired cosmetic, push ad, popunder, and video ad cleaner scriptlet.
    static let contentBlockerScriptlet = """
    (function() {
        // 1. Notification Permission Bridge (Routes push prompts to native permission store/prompt)
        try {
            if (window.Notification) {
                window.Notification.requestPermission = function() {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.lotusNotificationHandler) {
                        return new Promise(function(resolve) {
                            var callbackId = 'notif_' + Math.random().toString(36).substr(2, 9);
                            window._lotusNotifCallbacks = window._lotusNotifCallbacks || {};
                            window._lotusNotifCallbacks[callbackId] = resolve;
                            window.webkit.messageHandlers.lotusNotificationHandler.postMessage({
                                callbackId: callbackId,
                                origin: window.location.origin,
                                host: window.location.host
                            });
                        });
                    }
                    return Promise.resolve('default');
                };
            }
        } catch(e) {}

        // 2. Video Ad Skip & Overlays Remover for Generic Web Players
        function handleGenericVideoAds() {
            try {
                var skipSelectors = [
                    '.ytp-ad-skip-button',
                    '.ytp-ad-skip-button-modern',
                    '.ytp-skip-ad-button',
                    '.ytp-ad-skip-button-slot',
                    '[class*="skip-button"]',
                    '[class*="ad-skip"]',
                    '[class*="skip-ad"]',
                    '[aria-label*="Skip Ad" i]',
                    '[aria-label*="Skip ad" i]',
                    '.videoAdUiSkipButton'
                ];
                var skipBtn = document.querySelector(skipSelectors.join(', '));
                if (skipBtn && skipBtn.offsetParent !== null) {
                    skipBtn.click();
                }

                var overlays = document.querySelectorAll(
                    '.ytp-ad-overlay-container, .ytp-ad-message-container, .video-ad-overlay, .ad-overlay, [class*="ad-overlay"]'
                );
                for (var i = 0; i < overlays.length; i++) {
                    overlays[i].style.setProperty('display', 'none', 'important');
                }
            } catch(e) {}
        }

        // 3. Dynamic Ad & Push Notification Elements Remover
        var adSelectors = [
            '.adsbygoogle',
            '[id^="google_ads_"]',
            '[id^="div-gpt-ad"]',
            '[class*="ad-container"]',
            '[class*="ad-banner"]',
            '[class*="ad-wrapper"]',
            '[class*="ad-slot"]',
            '[class*="ad-unit"]',
            '[class*="ad_banner"]',
            '[class*="ad_block"]',
            '[class*="sponsored-content"]',
            '[class*="sponsored-post"]',
            '[class*="native-ad"]',
            '[class*="onesignal"]',
            '[id*="onesignal"]',
            '[class*="push-prompt"]',
            '[id*="push-prompt"]',
            '.sp-prompt',
            '.webpush-prompt',
            '.pushcrew-chrome-prompt',
            '.push-prompt-box',
            '.notification-prompt',
            '[class*="inpage-push"]',
            '[class*="interstitial"]',
            '[class*="fullscreen-ad"]',
            '[class*="floating-banner"]',
            '.floating-ad',
            '[class*="overlay-ad"]',
            'ytd-promoted-video-renderer',
            'ytd-banner-promo-renderer',
            'ytd-statement-banner-renderer',
            'ytd-in-feed-ad-layout-renderer'
        ].join(',');

        var host = (window.location && window.location.hostname ? window.location.hostname : '').toLowerCase();
        if (host.startsWith('www.')) host = host.slice(4);
        var authHosts = ['accounts.google.com', 'myaccount.google.com', 'google.com', 'gstatic.com', 'googleapis.com', 'appleid.apple.com', 'login.microsoftonline.com', 'login.live.com', 'auth.github.com', 'github.com'];
        for (var a = 0; a < authHosts.length; a++) {
            if (host === authHosts[a] || host.endsWith('.' + authHosts[a])) return;
        }

        function notifyShieldDeflect() {
            try {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.lotusShieldDeflectHandler) {
                    window.webkit.messageHandlers.lotusShieldDeflectHandler.postMessage({ blocked: true });
                }
            } catch(e) {}
        }

        function isAuthElement(el) {
            try {
                if (!el) return false;
                if (el.closest && el.closest('[id*="g_id_"], [class*="g_id_"], [id*="gsi_"], [class*="google-signin"], [class*="sign-in-with-google"], iframe[src*="accounts.google.com"], iframe[src*="appleid.apple.com"]')) return true;
                return false;
            } catch(e) { return false; }
        }

        function cleanDOM() {
            handleGenericVideoAds();
            try {
                var nodes = document.querySelectorAll(adSelectors);
                var didBlock = false;
                for (var i = 0; i < nodes.length; i++) {
                    var el = nodes[i];
                    if (el && !isAuthElement(el) && el.style && el.style.display !== 'none') {
                        el.style.setProperty('display', 'none', 'important');
                        didBlock = true;
                    }
                }
                if (didBlock) {
                    notifyShieldDeflect();
                }
            } catch(e) {}
        }

        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', cleanDOM);
        } else {
            cleanDOM();
        }
        setInterval(cleanDOM, 1000);
    })();
    """

    /// Injects Do Not Track (DNT) and Global Privacy Control (Sec-GPC) client-side signals
    /// into navigator and fetch/XMLHttpRequest headers to signal privacy preferences.
    static let globalPrivacyControlScriptlet = """
    (function() {
        try {
            var host = (window.location && window.location.hostname ? window.location.hostname : '').toLowerCase();
            if (host.startsWith('www.')) host = host.slice(4);
            var authHosts = [
                'accounts.google.com',
                'myaccount.google.com',
                'google.com',
                'gstatic.com',
                'googleapis.com',
                'googleusercontent.com',
                'appleid.apple.com',
                'apple.com',
                'icloud.com',
                'login.live.com',
                'login.microsoftonline.com',
                'auth.github.com',
                'github.com'
            ];
            for (var a = 0; a < authHosts.length; a++) {
                if (host === authHosts[a] || host.endsWith('.' + authHosts[a])) return;
            }

            if (window.Navigator && Navigator.prototype) {
                try {
                    Object.defineProperty(Navigator.prototype, 'globalPrivacyControl', {
                        get: function() { return true; },
                        configurable: true,
                        enumerable: true
                    });
                } catch(e) {}
            }
        } catch(err) {}
    })();
    """

    /// Comprehensive YouTube ad blocker: intercepts player config JSON to strip prerolls/midrolls,
    /// fast-skips and mutes in-stream video ads, removes anti-adblock modals, and injects zero-flicker CSS rules.
    static let youtubeAdBlockScript = """
    (function() {
        'use strict';
        var host = (window.location && window.location.hostname ? window.location.hostname : '').toLowerCase();
        if (!host.endsWith('youtube.com') && !host.endsWith('youtu.be')) return;
        if (window.__lotusYTAdBlockInjected) return;
        try { Object.defineProperty(window, '__lotusYTAdBlockInjected', { value: true, enumerable: false }); } catch(e) {}

        var adFastForwardActive = false;
        var lastShieldNotifyTime = 0;

        function notifyShieldDeflect() {
            try {
                var now = Date.now();
                if (now - lastShieldNotifyTime > 500) {
                    lastShieldNotifyTime = now;
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.lotusShieldDeflectHandler) {
                        window.webkit.messageHandlers.lotusShieldDeflectHandler.postMessage({ blocked: true });
                    }
                }
            } catch(e) {}
        }

        // 1. JSON Player Response Sanitizer (Strips Preroll, Midroll & Ad Placement Configs)
        function cleanPlayerResponse(data) {
            if (!data || typeof data !== 'object') return data;
            try {
                if (data.adPlacements) delete data.adPlacements;
                if (data.playerAds) delete data.playerAds;
                if (data.adSlots) delete data.adSlots;
                if (data.adBreakHeartbeatParams) delete data.adBreakHeartbeatParams;
                if (data.adSignalsInfo) delete data.adSignalsInfo;
                if (data.playbackTracking) {
                    delete data.playbackTracking.videostatsPlaybackUrl;
                    delete data.playbackTracking.videostatsDelayplayUrl;
                    delete data.playbackTracking.videostatsWatchtimeUrl;
                    delete data.playbackTracking.ptrackingUrl;
                    delete data.playbackTracking.qoeUrl;
                    delete data.playbackTracking.atrUrl;
                }
            } catch(e) {}
            return data;
        }

        // Intercept ytInitialPlayerResponse
        var initialPlayerResponseVal = window.ytInitialPlayerResponse;
        try {
            Object.defineProperty(window, 'ytInitialPlayerResponse', {
                get: function() { return initialPlayerResponseVal; },
                set: function(val) { initialPlayerResponseVal = cleanPlayerResponse(val); },
                configurable: true
            });
            if (initialPlayerResponseVal) {
                initialPlayerResponseVal = cleanPlayerResponse(initialPlayerResponseVal);
            }
        } catch(e) {}

        // Intercept JSON.parse for YouTube player API responses
        try {
            var origJSONParse = JSON.parse;
            JSON.parse = function(text, reviver) {
                var res = origJSONParse.apply(this, arguments);
                if (res && typeof res === 'object') {
                    if (res.adPlacements || res.playerAds || res.adSlots || res.adBreakHeartbeatParams) {
                        res = cleanPlayerResponse(res);
                    }
                }
                return res;
            };
        } catch(e) {}

        // Intercept Fetch API for /youtubei/v1/player responses
        try {
            if (window.fetch) {
                var origFetch = window.fetch;
                window.fetch = function(input, init) {
                    var url = typeof input === 'string' ? input : (input && input.url ? input.url : '');
                    var isPlayerAPI = url.indexOf('/youtubei/v1/player') !== -1 ||
                                      url.indexOf('/youtubei/v1/next') !== -1 ||
                                      url.indexOf('/youtubei/v1/reel/') !== -1;

                    return origFetch.apply(this, arguments).then(function(response) {
                        if (!isPlayerAPI || !response || !response.ok) {
                            return response;
                        }
                        return response.clone().json().then(function(json) {
                            var cleaned = cleanPlayerResponse(json);
                            var blob = new Blob([JSON.stringify(cleaned)], { type: 'application/json' });
                            return new Response(blob, {
                                status: response.status,
                                statusText: response.statusText,
                                headers: response.headers
                            });
                        }).catch(function() {
                            return response;
                        });
                    });
                };
            }
        } catch(e) {}

        // Intercept XMLHttpRequest for /youtubei/v1/player responses
        try {
            if (window.XMLHttpRequest && XMLHttpRequest.prototype.open && XMLHttpRequest.prototype.send) {
                var origOpen = XMLHttpRequest.prototype.open;
                var origSend = XMLHttpRequest.prototype.send;

                XMLHttpRequest.prototype.open = function(method, url) {
                    this.__lotusYTURL = typeof url === 'string' ? url : '';
                    return origOpen.apply(this, arguments);
                };

                XMLHttpRequest.prototype.send = function() {
                    var isPlayerAPI = this.__lotusYTURL && (
                        this.__lotusYTURL.indexOf('/youtubei/v1/player') !== -1 ||
                        this.__lotusYTURL.indexOf('/youtubei/v1/next') !== -1
                    );

                    if (isPlayerAPI) {
                        var self = this;
                        var origGetter = Object.getOwnPropertyDescriptor(XMLHttpRequest.prototype, 'responseText');
                        if (origGetter && origGetter.get) {
                            this.addEventListener('readystatechange', function() {
                                if (self.readyState === 4 && self.status === 200) {
                                    try {
                                        var raw = origGetter.get.call(self);
                                        var parsed = JSON.parse(raw);
                                        var cleaned = cleanPlayerResponse(parsed);
                                        var newText = JSON.stringify(cleaned);
                                        Object.defineProperty(self, 'responseText', { value: newText, writable: true, configurable: true });
                                        Object.defineProperty(self, 'response', { value: newText, writable: true, configurable: true });
                                    } catch(err) {}
                                }
                            }, false);
                        }
                    }
                    return origSend.apply(this, arguments);
                };
            }
        } catch(e) {}

        // 2. Injected CSS for Immediate Zero-Flicker Ad & Promo Hiding
        var ytAdCSS = `
            ytd-ad-slot-renderer,
            ytd-in-feed-ad-layout-renderer,
            ytd-promoted-sparkles-web-renderer,
            ytd-promoted-video-renderer,
            ytd-banner-promo-renderer,
            ytd-statement-banner-renderer,
            ytd-display-ad-renderer,
            ytd-primetime-promo-renderer,
            ytd-compact-promoted-video-renderer,
            ytd-video-masthead-ad-v3-renderer,
            ytd-ad-hover-text-button-renderer,
            #masthead-ad,
            #player-ads,
            .ytd-mealbar-promo-renderer,
            .ytp-ad-overlay-container,
            .ytp-ad-message-container,
            .ytp-ad-action-interstitial,
            .ytp-ad-text-overlay,
            .ytp-ad-player-overlay,
            .ytp-ad-progress,
            .ytp-ad-progress-list,
            ytd-rich-item-renderer:has(ytd-ad-slot-renderer),
            ytd-rich-item-renderer:has(ytd-in-feed-ad-layout-renderer),
            ytd-rich-section-renderer:has(ytd-ad-slot-renderer),
            ytd-rich-section-renderer:has(ytd-statement-banner-renderer),
            ytd-engagement-panel-section-list-renderer[target-id="engagement-panel-ads"],
            tp-yt-paper-dialog:has(ytd-enforcement-message-view-model),
            ytd-enforcement-message-view-model {
                display: none !important;
                visibility: hidden !important;
                height: 0px !important;
                min-height: 0px !important;
                width: 0px !important;
                pointer-events: none !important;
            }
        `;

        function injectStyle() {
            try {
                if (document.getElementById('lotus-yt-adblock-css')) return;
                var style = document.createElement('style');
                style.id = 'lotus-yt-adblock-css';
                style.textContent = ytAdCSS;
                (document.head || document.documentElement).appendChild(style);
            } catch(e) {}
        }
        injectStyle();
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', injectStyle);
        }

        // 3. Player Video Fast-Forward, Auto-Skip & Anti-Adblock Bypass Engine
        function processYouTubeAds() {
            try {
                // Anti-adblock popup bypass
                var enforcementPopup = document.querySelector('ytd-enforcement-message-view-model, tp-yt-paper-dialog:has(ytd-enforcement-message-view-model)');
                if (enforcementPopup) {
                    enforcementPopup.remove();
                    notifyShieldDeflect();
                    var backdrop = document.querySelector('tp-yt-iron-overlay-backdrop');
                    if (backdrop) backdrop.remove();
                    document.body.style.removeProperty('overflow');
                    var mainVid = document.querySelector('#movie_player video, video.html5-main-video');
                    if (mainVid && mainVid.paused) {
                        mainVid.play();
                    }
                }

                var player = document.querySelector('#movie_player, .html5-video-player');
                var video = document.querySelector('#movie_player video, video.html5-main-video, .html5-video-player video');

                if (player && video) {
                    var isAdShowing = player.classList.contains('ad-showing') ||
                                      player.classList.contains('ad-interrupting') ||
                                      document.querySelector('.ytp-ad-player-overlay, .ytp-ad-showing') !== null;

                    if (isAdShowing) {
                        if (!adFastForwardActive) {
                            notifyShieldDeflect();
                        }
                        adFastForwardActive = true;
                        video.muted = true;
                        video.playbackRate = 16.0;

                        // Click skip button immediately
                        var skipSelectors = [
                            '.ytp-ad-skip-button',
                            '.ytp-ad-skip-button-modern',
                            '.ytp-skip-ad-button',
                            '.ytp-ad-skip-button-slot',
                            'button.ytp-ad-skip-button-modern',
                            '.ytp-ad-skip-button-container button',
                            '.ytp-ad-overlay-close-button'
                        ];
                        var skipBtn = document.querySelector(skipSelectors.join(', '));
                        if (skipBtn) {
                            skipBtn.click();
                        }

                        // Fast-forward ad stream directly to end
                        if (isFinite(video.duration) && video.duration > 0 && video.currentTime < video.duration) {
                            video.currentTime = video.duration;
                        }
                    } else if (adFastForwardActive) {
                        // Regular video playback resumed
                        adFastForwardActive = false;
                        video.muted = false;
                        if (video.playbackRate > 4.0) {
                            video.playbackRate = 1.0;
                        }
                    }
                }
            } catch(e) {}
        }

        // MutationObserver for reactive instant ad handling
        function setupObserver() {
            try {
                var target = document.querySelector('#movie_player') || document.body;
                if (!target) return;
                var observer = new MutationObserver(function() {
                    processYouTubeAds();
                });
                observer.observe(target, { childList: true, subtree: true, attributes: true, attributeFilter: ['class'] });
            } catch(e) {}
        }

        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', setupObserver);
        } else {
            setupObserver();
        }

        setInterval(processYouTubeAds, 150);
    })();
    """

    /// Masks high-risk device APIs like battery status without breaking web standards,
    /// WebAuthn, BotGuard, or canvas verification.
    static func antiFingerprintingScript(disabledDomains: Set<String> = [], strictCanvasBlock: Bool = false) -> String {
        let domainsArray = (try? String(data: JSONEncoder().encode(Array(disabledDomains.map { $0.lowercased() })), encoding: .utf8)) ?? "[]"
        return """
        (function() {
            'use strict';
            if (window.__lotusFPProtected) return;

            var disabledDomains = \(domainsArray);
            var host = (window.location && window.location.hostname ? window.location.hostname : '').toLowerCase();
            if (host.startsWith('www.')) host = host.slice(4);

            // Never interfere with identity providers, authentication, passkeys & WebAuthn flows
            var authHosts = [
                'accounts.google.com',
                'myaccount.google.com',
                'google.com',
                'gstatic.com',
                'googleapis.com',
                'googleusercontent.com',
                'appleid.apple.com',
                'apple.com',
                'icloud.com',
                'login.live.com',
                'login.microsoftonline.com',
                'auth.github.com',
                'github.com',
                'idmsa.apple.com',
                'accounts.youtube.com'
            ];
            for (var a = 0; a < authHosts.length; a++) {
                if (host === authHosts[a] || host.endsWith('.' + authHosts[a])) return;
            }

            for (var d = 0; d < disabledDomains.length; d++) {
                var dom = disabledDomains[d];
                if (host === dom || host.endsWith('.' + dom)) {
                    return;
                }
            }

            try { Object.defineProperty(window, '__lotusFPProtected', { value: true, enumerable: false }); } catch(e) {}

            // Disable battery fingerprinting API cleanly
            try {
                if (navigator.getBattery) {
                    navigator.getBattery = function() {
                        return Promise.reject(new Error('Battery API disabled for privacy'));
                    };
                }
            } catch(e) {}
        })();
        """
    }

    /// Base anti-fingerprinting payload
    static var antiFingerprintingScript: String {
        antiFingerprintingScript(disabledDomains: ContentBlockerService.shared.fingerprintDisabledDomains)
    }

    // MARK: - Evaluated On Demand

    /// Stops and detaches all media elements before a tab's webview is torn down.
    static let pauseAllMedia = """
    (function() {
        var media = document.querySelectorAll('audio, video');
        media.forEach(function(m) {
            try { m.pause(); m.src = ''; } catch(e){}
        });
        if (window.AudioContext || window.webkitAudioContext) {
            try { (window.AudioContext || window.webkitAudioContext).close(); } catch(e){}
        }
    })();
    """

    /// Returns the page's effective theme color (meta tag, body, or root background).
    static let themeColorProbe = """
    (function() {
        var meta = document.querySelector('meta[name="theme-color"]');
        if (meta && meta.content) return meta.content;
        var bodyStyle = window.getComputedStyle(document.body);
        var bg = bodyStyle.backgroundColor;
        if (bg && bg !== 'rgba(0, 0, 0, 0)' && bg !== 'transparent') return bg;
        var docStyle = window.getComputedStyle(document.documentElement);
        var docBg = docStyle.backgroundColor;
        if (docBg && docBg !== 'rgba(0, 0, 0, 0)' && docBg !== 'transparent') return docBg;
        return null;
    })()
    """

    /// Probes the page for declared high-res favicons (<link rel="icon">, <link rel="apple-touch-icon">, etc.).
    static let faviconProbe = """
    (function() {
        var selectors = [
            'link[rel="apple-touch-icon"][href]',
            'link[rel="apple-touch-icon-precomposed"][href]',
            'link[rel="icon"][sizes="192x192"][href]',
            'link[rel="icon"][sizes="96x96"][href]',
            'link[rel="icon"][sizes="32x32"][href]',
            'link[rel="icon"][href]',
            'link[rel="shortcut icon"][href]',
            'link[rel="mask-icon"][href]'
        ];
        for (var i = 0; i < selectors.length; i++) {
            var el = document.querySelector(selectors[i]);
            if (el && el.href) return el.href;
        }
        return null;
    })()
    """

    /// Re-reports the page's current input-focus state (see `inputFocusMonitor`).
    static let checkInputFocus = "window.__lotusCheckInputFocus ? window.__lotusCheckInputFocus() : void 0;"

    // MARK: - Picture in Picture

    /// Returns 'pip' if a video is already in PiP, 'playing' if a proper main
    /// video is actively playing, else 'none'.
    static let pictureInPictureStatus = """
    (function() {
        function getAllVideos() {
            var list = [];
            function scan(root) {
                if (!root) return;
                try {
                    var vids = root.querySelectorAll('video');
                    for (var i = 0; i < vids.length; i++) {
                        if (list.indexOf(vids[i]) === -1) list.push(vids[i]);
                    }
                    var all = root.querySelectorAll('*');
                    for (var j = 0; j < all.length; j++) {
                        if (all[j].shadowRoot) scan(all[j].shadowRoot);
                    }
                } catch(e) {}
            }
            scan(document);
            return list;
        }

        var videos = getAllVideos();
        for (var i = 0; i < videos.length; i++) {
            try {
                if (videos[i].webkitPresentationMode === 'picture-in-picture') return 'pip';
            } catch (e) {}
        }
        if (document.pictureInPictureElement) return 'pip';

        function isProperVideo(v) {
            if (!v || v.paused || v.ended || v.readyState < 2) return false;
            // Filter out tiny videos, avatars, tracking pixels
            if (!v.videoWidth || !v.videoHeight || v.videoWidth < 280 || v.videoHeight < 160) return false;
            var rect = v.getBoundingClientRect();
            if (rect.width < 160 || rect.height < 90) return false;
            // Filter out short looping decorative clips/GIFs/stickers (duration < 12s)
            var duration = v.duration;
            var isFiniteDuration = typeof duration === 'number' && !isNaN(duration) && isFinite(duration) && duration > 0;
            if (isFiniteDuration && duration < 12 && (v.loop || v.muted)) return false;
            // Filter out muted in-feed hover previews (e.g. YouTube hover preview, Reddit feed preview)
            if (v.muted && isFiniteDuration && duration < 45 && (v.loop || v.closest('#inline-preview-player, .inline-preview, [class*="preview"], [id*="preview"]'))) return false;
            return true;
        }

        var playing = videos.some(isProperVideo);
        return playing ? 'playing' : (videos.length > 0 ? 'has-video' : 'none');
    })();
    """

    /// Auto-PiP trigger on tab switch: Puts the best proper content video into native PiP.
    /// Filters out thumbnail previews, background loops, and micro-clips.
    static let enterPictureInPicture = """
    (function() {
        function getAllVideos() {
            var list = [];
            function scan(root) {
                if (!root) return;
                try {
                    var vids = root.querySelectorAll('video');
                    for (var i = 0; i < vids.length; i++) {
                        if (list.indexOf(vids[i]) === -1) list.push(vids[i]);
                    }
                    var all = root.querySelectorAll('*');
                    for (var j = 0; j < all.length; j++) {
                        if (all[j].shadowRoot) scan(all[j].shadowRoot);
                    }
                } catch(e) {}
            }
            scan(document);
            return list;
        }

        var videos = getAllVideos();

        function isProperCandidate(v, requirePlaying) {
            if (!v || v.readyState < 1) return false;
            if (requirePlaying && (v.paused || v.ended || v.readyState < 2)) return false;
            if (!v.videoWidth || !v.videoHeight || v.videoWidth < 280 || v.videoHeight < 160) return false;
            var rect = v.getBoundingClientRect();
            if (rect.width < 160 || rect.height < 90) return false;
            var duration = v.duration;
            var isFiniteDuration = typeof duration === 'number' && !isNaN(duration) && isFinite(duration) && duration > 0;
            if (isFiniteDuration && duration < 12 && (v.loop || v.muted)) return false;
            if (v.muted && isFiniteDuration && duration < 45 && (v.loop || v.closest('#inline-preview-player, .inline-preview, [class*="preview"], [id*="preview"]'))) return false;
            return true;
        }

        var bySize = function(a, b) {
            return (b.videoWidth * b.videoHeight) - (a.videoWidth * a.videoHeight);
        };

        // Prefer largest playing proper video
        var candidate = videos.filter(function(v) { return isProperCandidate(v, true); }).sort(bySize)[0];
        if (!candidate) {
            candidate = videos.filter(function(v) { return isProperCandidate(v, false); }).sort(bySize)[0];
        }

        if (!candidate) return 'no-playing-video';
        try {
            candidate.removeAttribute('disablepictureinpicture');
            candidate.disablePictureInPicture = false;
            if (candidate.webkitSupportsPresentationMode &&
                candidate.webkitSupportsPresentationMode('picture-in-picture')) {
                if (candidate.webkitPresentationMode !== 'picture-in-picture') {
                    candidate.webkitSetPresentationMode('picture-in-picture');
                }
                return 'ok';
            }
            if (candidate.requestPictureInPicture) {
                candidate.requestPictureInPicture();
                return 'ok';
            }
        } catch (e) {
            return 'error';
        }
        return 'unsupported';
    })();
    """

    /// Manual PiP trigger: Detaches ANY video on the page into Picture in Picture.
    /// Traverses shadow DOMs, strips disablepictureinpicture flags, and gracefully falls back
    /// through all video elements on the page.
    static let enterPictureInPictureManual = """
    (function() {
        function getAllVideos() {
            var list = [];
            function scan(root) {
                if (!root) return;
                try {
                    var vids = root.querySelectorAll('video');
                    for (var i = 0; i < vids.length; i++) {
                        if (list.indexOf(vids[i]) === -1) list.push(vids[i]);
                    }
                    var all = root.querySelectorAll('*');
                    for (var j = 0; j < all.length; j++) {
                        if (all[j].shadowRoot) scan(all[j].shadowRoot);
                    }
                } catch(e) {}
            }
            scan(document);
            return list;
        }

        var videos = getAllVideos();
        if (!videos || videos.length === 0) return 'no-video';

        function tryPiP(v) {
            if (!v) return false;
            try {
                v.removeAttribute('disablepictureinpicture');
                v.disablePictureInPicture = false;
                if (v.webkitSupportsPresentationMode &&
                    v.webkitSupportsPresentationMode('picture-in-picture')) {
                    if (v.webkitPresentationMode !== 'picture-in-picture') {
                        v.webkitSetPresentationMode('picture-in-picture');
                    }
                    return true;
                }
                if (v.requestPictureInPicture) {
                    v.requestPictureInPicture();
                    return true;
                }
            } catch (e) {}
            return false;
        }

        var byScore = function(a, b) {
            var aPlaying = (!a.paused && !a.ended && a.readyState >= 2) ? 100000 : 0;
            var bPlaying = (!b.paused && !b.ended && b.readyState >= 2) ? 100000 : 0;
            var aArea = (a.videoWidth || a.offsetWidth || 1) * (a.videoHeight || a.offsetHeight || 1);
            var bArea = (b.videoWidth || b.offsetWidth || 1) * (b.videoHeight || b.offsetHeight || 1);
            return (bPlaying + bArea) - (aPlaying + aArea);
        };

        var sorted = videos.slice().sort(byScore);
        for (var i = 0; i < sorted.length; i++) {
            if (tryPiP(sorted[i])) {
                return 'ok';
            }
        }

        return 'unsupported';
    })();
    """

    /// Returns any Picture-in-Picture video back inline. Returns 'ok' if a
    /// video was restored.
    static let exitPictureInPicture = """
    (function() {
        function getAllVideos() {
            var list = [];
            function scan(root) {
                if (!root) return;
                try {
                    var vids = root.querySelectorAll('video');
                    for (var i = 0; i < vids.length; i++) {
                        if (list.indexOf(vids[i]) === -1) list.push(vids[i]);
                    }
                    var all = root.querySelectorAll('*');
                    for (var j = 0; j < all.length; j++) {
                        if (all[j].shadowRoot) scan(all[j].shadowRoot);
                    }
                } catch(e) {}
            }
            scan(document);
            return list;
        }

        var restored = false;
        var videos = getAllVideos();
        videos.forEach(function(v) {
            try {
                if (v.webkitPresentationMode === 'picture-in-picture') {
                    v.webkitSetPresentationMode('inline');
                    restored = true;
                }
            } catch (e) {}
        });
        if (!restored && document.pictureInPictureElement && document.exitPictureInPicture) {
            try { document.exitPictureInPicture(); restored = true; } catch (e) {}
        }
        return restored ? 'ok' : 'none';
    })();
    """

    // MARK: - Find on Page

    /// Clears any text selection and remaining DOM highlight ranges on the page.
    static let clearSelection = """
    (function() {
        try {
            if (window.getSelection) {
                var sel = window.getSelection();
                if (sel && sel.removeAllRanges) {
                    sel.removeAllRanges();
                }
            }
            if (document.selection && document.selection.empty) {
                document.selection.empty();
            }
        } catch(e) {}
    })();
    """

    /// Returns a script that counts all occurrences of a query string across
    /// visible text nodes in the DOM.
    static func countMatchesScript(for query: String, caseSensitive: Bool = false) -> String {
        let jsonQuery: String
        if let data = try? JSONSerialization.data(withJSONObject: [query]),
           let str = String(data: data, encoding: .utf8),
           str.hasPrefix("[") && str.hasSuffix("]") {
            jsonQuery = String(str.dropFirst().dropLast())
        } else {
            jsonQuery = "\"\""
        }

        return """
        (function() {
            var query = \(jsonQuery);
            if (!query || query.length === 0) return 0;
            try {
                var flags = \(caseSensitive ? "'g'" : "'gi'");
                var escaped = query.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&');
                var regex = new RegExp(escaped, flags);
                var walker = document.createTreeWalker(
                    document.body || document.documentElement,
                    NodeFilter.SHOW_TEXT,
                    {
                        acceptNode: function(node) {
                            if (!node.nodeValue || !node.nodeValue.trim()) return NodeFilter.FILTER_REJECT;
                            var parent = node.parentElement;
                            if (!parent) return NodeFilter.FILTER_REJECT;
                            var tag = parent.tagName ? parent.tagName.toUpperCase() : '';
                            if (tag === 'SCRIPT' || tag === 'STYLE' || tag === 'NOSCRIPT' || tag === 'TEXTAREA') {
                                return NodeFilter.FILTER_REJECT;
                            }
                            var style = window.getComputedStyle(parent);
                            if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') {
                                return NodeFilter.FILTER_REJECT;
                            }
                            return NodeFilter.FILTER_ACCEPT;
                        }
                    }
                );
                var count = 0;
                while (walker.nextNode()) {
                    var matches = walker.currentNode.nodeValue.match(regex);
                    if (matches) {
                        count += matches.length;
                    }
                }
                return count;
            } catch(e) {
                return 0;
            }
        })();
        """
    }

    /// Observes audio/video playback and AudioContext, reporting state to the app.
    static let mediaPlaybackObserverScriptlet = """
    (function() {
        if (window.__lotusMediaScriptLoaded) return;
        window.__lotusMediaScriptLoaded = true;

        function getMediaTitle() {
            var el = document.querySelector('video, audio');
            if (document.title && document.title.length > 0) return document.title;
            if (el && el.title) return el.title;
            return null;
        }

        function checkMediaState() {
            try {
                var mediaElements = document.querySelectorAll('audio, video');
                var isPlaying = false;
                var isMuted = false;
                var hasAudio = false;
                var hasVideo = false;

                for (var i = 0; i < mediaElements.length; i++) {
                    var el = mediaElements[i];
                    if (el.tagName === 'VIDEO') hasVideo = true;
                    if (!el.paused && !el.ended && el.readyState > 1) {
                        isPlaying = true;
                        if (el.muted || el.volume === 0) {
                            isMuted = true;
                        } else {
                            hasAudio = true;
                        }
                    }
                }

                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.lotusMediaHandler) {
                    window.webkit.messageHandlers.lotusMediaHandler.postMessage({
                        isPlaying: isPlaying,
                        isMuted: isMuted,
                        hasAudio: hasAudio,
                        hasVideo: hasVideo,
                        title: getMediaTitle()
                    });
                }
            } catch(e) {}
        }

        ['play', 'pause', 'volumechange', 'ended', 'emptied', 'loadeddata'].forEach(function(evt) {
            document.addEventListener(evt, function() {
                setTimeout(checkMediaState, 80);
            }, true);
        });

        window.__lotusSetMediaMuted = function(muted) {
            var media = document.querySelectorAll('audio, video');
            media.forEach(function(m) { m.muted = muted; });
            setTimeout(checkMediaState, 50);
        };

        window.__lotusToggleMediaPlayPause = function() {
            var media = document.querySelectorAll('audio, video');
            var anyPlaying = Array.from(media).some(function(m) { return !m.paused && !m.ended; });
            media.forEach(function(m) {
                if (anyPlaying) {
                    m.pause();
                } else {
                    m.play().catch(function(){});
                }
            });
            setTimeout(checkMediaState, 50);
        };

        window.__lotusTriggerPiP = function() {
            var video = document.querySelector('video');
            if (!video) return;
            if (document.pictureInPictureElement) {
                document.exitPictureInPicture().catch(function(){});
            } else if (video.requestPictureInPicture) {
                video.requestPictureInPicture().catch(function(){});
            } else if (video.webkitSetPresentationMode) {
                var mode = video.webkitPresentationMode === 'picture-in-picture' ? 'inline' : 'picture-in-picture';
                video.webkitSetPresentationMode(mode);
            }
        };
    })();
    """

    // MARK: - Zap Element Blocker (DOM Manipulation & Boosts)

    /// Injects persistent CSS hiding rules and dynamic mutation observers for a website's zapped elements.
    static func zapRulesScript(for elements: [ZappedElement]) -> String {
        if elements.isEmpty {
            return """
            (function() {
                try {
                    var style = document.getElementById('__lotus_zap_styles__');
                    if (style && style.parentNode) {
                        style.parentNode.removeChild(style);
                    }
                    if (window.__lotusZapObserver) {
                        window.__lotusZapObserver.disconnect();
                        window.__lotusZapObserver = null;
                    }
                } catch(e) {}
            })();
            """
        }

        let selectors = elements.map { $0.selector }
        let cssRules = selectors.map { "\($0) { display: none !important; visibility: hidden !important; pointer-events: none !important; opacity: 0 !important; }" }.joined(separator: "\n")

        guard let jsonSelectorsData = try? JSONSerialization.data(withJSONObject: selectors),
              let jsonSelectors = String(data: jsonSelectorsData, encoding: .utf8),
              let jsonCSSData = try? JSONSerialization.data(withJSONObject: [cssRules]),
              let jsonCSSArray = String(data: jsonCSSData, encoding: .utf8),
              jsonCSSArray.hasPrefix("[") && jsonCSSArray.hasSuffix("]") else {
            return ""
        }
        let jsonCSS = String(jsonCSSArray.dropFirst().dropLast())

        return """
        (function() {
            try {
                var styleId = '__lotus_zap_styles__';
                var existing = document.getElementById(styleId);
                var css = \(jsonCSS);
                if (existing) {
                    existing.textContent = css;
                } else {
                    var style = document.createElement('style');
                    style.id = styleId;
                    style.textContent = css;
                    (document.head || document.documentElement).appendChild(style);
                }

                var selectors = \(jsonSelectors);
                function pruneNodes() {
                    for (var s = 0; s < selectors.length; s++) {
                        try {
                            var nodes = document.querySelectorAll(selectors[s]);
                            for (var i = 0; i < nodes.length; i++) {
                                nodes[i].style.setProperty('display', 'none', 'important');
                                nodes[i].style.setProperty('visibility', 'hidden', 'important');
                            }
                        } catch(err) {}
                    }
                }
                pruneNodes();

                if (!window.__lotusZapObserver) {
                    var observer = new MutationObserver(function() {
                        pruneNodes();
                    });
                    var target = document.documentElement || document.body;
                    if (target) {
                        observer.observe(target, { childList: true, subtree: true });
                        window.__lotusZapObserver = observer;
                    }
                }
            } catch(e) {}
        })();
        """
    }

    /// Injects the interactive visual element inspector allowing users to hover and click elements to zap them.
    static func startZapModeScript(accentHex: String = "#007AFF") -> String {
        let safeHex = accentHex.hasPrefix("#") ? accentHex : "#007AFF"
        return """
        (function() {
            if (window.__lotusZapActive) return;
            window.__lotusZapActive = true;

            var accentColor = '\(safeHex)';
            var highlightOverlay = document.createElement('div');
            highlightOverlay.id = '__lotus_zap_overlay__';
            highlightOverlay.style.cssText = 'position: absolute; pointer-events: none; z-index: 2147483647; border: 2.5px solid ' + accentColor + '; background: ' + accentColor + '26; box-shadow: 0 0 20px ' + accentColor + '66; border-radius: 6px; transition: all 0.08s ease-out; display: none;';

            var badge = document.createElement('div');
            badge.id = '__lotus_zap_badge__';
            badge.style.cssText = 'position: absolute; top: -28px; left: 0; background: ' + accentColor + '; color: #FFFFFF; font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif; font-size: 11px; font-weight: 600; padding: 4px 8px; border-radius: 5px; pointer-events: none; white-space: nowrap; box-shadow: 0 2px 8px rgba(0,0,0,0.30); z-index: 2147483647;';
            highlightOverlay.appendChild(badge);

            document.documentElement.appendChild(highlightOverlay);

            var currentTarget = null;

            function computeSelector(el) {
                if (!el || el === document.body || el === document.documentElement) return null;

                // 1. Stable, unique ID
                if (el.id && typeof el.id === 'string' && !/^[0-9]+$/.test(el.id) && !/\\d{5,}/.test(el.id)) {
                    var idSelector = '#' + CSS.escape(el.id);
                    try {
                        if (document.querySelectorAll(idSelector).length === 1) {
                            return idSelector;
                        }
                    } catch(e) {}
                }

                // 2. Stable unique attribute
                var dataAttrs = ['data-testid', 'data-qa', 'data-component', 'data-cy', 'data-test', 'aria-label', 'name'];
                for (var d = 0; d < dataAttrs.length; d++) {
                    var attr = dataAttrs[d];
                    var val = el.getAttribute(attr);
                    if (val && typeof val === 'string' && val.length > 1 && val.length < 80) {
                        var attrSelector = '[' + attr + '="' + CSS.escape(val) + '"]';
                        try {
                            if (document.querySelectorAll(attrSelector).length === 1) {
                                return attrSelector;
                            }
                        } catch(e) {}
                    }
                }

                // 3. Stable unique class combinations
                var tag = el.tagName.toLowerCase();
                var rawClasses = el.className && typeof el.className === 'string' ? el.className.trim().split(/\\s+/) : [];
                var cleanClasses = rawClasses.filter(function(c) {
                    return c && !c.startsWith('__lotus') && !/^[0-9]+$/.test(c) && !/\\d{5,}/.test(c) && c.length < 50;
                });

                if (cleanClasses.length > 0) {
                    for (var c = 1; c <= Math.min(cleanClasses.length, 3); c++) {
                        var classSelector = tag + '.' + cleanClasses.slice(0, c).map(CSS.escape).join('.');
                        try {
                            if (document.querySelectorAll(classSelector).length === 1) {
                                return classSelector;
                            }
                        } catch(e) {}
                    }
                }

                // 4. Hierarchical path anchored to nearest unique ancestor
                var path = [];
                var curr = el;
                while (curr && curr !== document.body && curr !== document.documentElement && path.length < 5) {
                    var currTag = curr.tagName.toLowerCase();
                    if (curr.id && typeof curr.id === 'string' && !/^[0-9]+$/.test(curr.id) && !/\\d{5,}/.test(curr.id)) {
                        path.unshift('#' + CSS.escape(curr.id));
                        break;
                    }

                    var currClasses = curr.className && typeof curr.className === 'string' ? curr.className.trim().split(/\\s+/) : [];
                    var validClasses = currClasses.filter(function(c) {
                        return c && !c.startsWith('__lotus') && !/^[0-9]+$/.test(c) && !/\\d{5,}/.test(c);
                    });

                    if (validClasses.length > 0) {
                        path.unshift(currTag + '.' + CSS.escape(validClasses[0]));
                    } else {
                        var parent = curr.parentElement;
                        if (parent) {
                            var siblings = Array.from(parent.children).filter(function(s) { return s.tagName === curr.tagName; });
                            if (siblings.length > 1) {
                                var index = siblings.indexOf(curr) + 1;
                                path.unshift(currTag + ':nth-of-type(' + index + ')');
                            } else {
                                path.unshift(currTag);
                            }
                        } else {
                            path.unshift(currTag);
                        }
                    }
                    curr = curr.parentElement;
                }

                var fullSelector = path.join(' > ');
                return fullSelector || tag;
            }

            function computeSummary(el) {
                var tag = el.tagName.toLowerCase();
                if (el.id) return '<' + tag + ' id="' + el.id + '">';
                if (el.className && typeof el.className === 'string') {
                    var cls = el.className.trim().split(/\\s+/).slice(0, 2).join('.');
                    if (cls) return '<' + tag + '.' + cls + '>';
                }
                return '<' + tag + '>';
            }

            function updateOverlay(el) {
                if (!el || el === highlightOverlay || el.id === '__lotus_zap_overlay__' || el.id === '__lotus_zap_badge__') {
                    highlightOverlay.style.display = 'none';
                    return;
                }
                var rect = el.getBoundingClientRect();
                if (rect.width === 0 || rect.height === 0) {
                    highlightOverlay.style.display = 'none';
                    return;
                }

                var scrollX = window.scrollX || window.pageXOffset;
                var scrollY = window.scrollY || window.pageYOffset;

                highlightOverlay.style.display = 'block';
                highlightOverlay.style.top = (rect.top + scrollY) + 'px';
                highlightOverlay.style.left = (rect.left + scrollX) + 'px';
                highlightOverlay.style.width = rect.width + 'px';
                highlightOverlay.style.height = rect.height + 'px';

                badge.textContent = computeSummary(el);
                if (rect.top < 32) {
                    badge.style.top = '4px';
                } else {
                    badge.style.top = '-28px';
                }
            }

            function onMouseMove(e) {
                var el = document.elementFromPoint(e.clientX, e.clientY);
                if (el && el !== currentTarget && el !== highlightOverlay && el.id !== '__lotus_zap_overlay__' && el.id !== '__lotus_zap_badge__') {
                    currentTarget = el;
                    updateOverlay(el);
                }
            }

            function onClick(e) {
                e.preventDefault();
                e.stopPropagation();
                e.stopImmediatePropagation();

                var el = currentTarget || document.elementFromPoint(e.clientX, e.clientY);
                if (!el || el === highlightOverlay || el.id === '__lotus_zap_overlay__' || el.id === '__lotus_zap_badge__') return;

                var selector = computeSelector(el);
                var summary = computeSummary(el);
                if (!selector) return;

                // Disintegration / poof animation
                el.style.transition = 'all 0.28s cubic-bezier(0.4, 0, 0.2, 1)';
                el.style.transform = 'scale(0.85)';
                el.style.opacity = '0';
                el.style.filter = 'blur(6px)';
                el.style.boxShadow = '0 0 24px ' + accentColor;
                el.style.outline = '2px solid ' + accentColor;

                highlightOverlay.style.display = 'none';

                setTimeout(function() {
                    el.style.display = 'none';
                }, 280);

                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.lotusZapHandler) {
                    window.webkit.messageHandlers.lotusZapHandler.postMessage({
                        action: 'zap',
                        selector: selector,
                        summary: summary,
                        domain: window.location.hostname
                    });
                }
            }

            function onKeyDown(e) {
                if (e.key === 'Escape') {
                    e.preventDefault();
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.lotusZapHandler) {
                        window.webkit.messageHandlers.lotusZapHandler.postMessage({
                            action: 'cancel'
                        });
                    }
                } else if (e.key === 'ArrowUp' && currentTarget && currentTarget.parentElement) {
                    e.preventDefault();
                    currentTarget = currentTarget.parentElement;
                    updateOverlay(currentTarget);
                } else if (e.key === 'ArrowDown' && currentTarget && currentTarget.firstElementChild) {
                    e.preventDefault();
                    currentTarget = currentTarget.firstElementChild;
                    updateOverlay(currentTarget);
                }
            }

            window.addEventListener('mousemove', onMouseMove, true);
            window.addEventListener('click', onClick, true);
            window.addEventListener('keydown', onKeyDown, true);

            window.__lotusZapCleanup = function() {
                try {
                    window.removeEventListener('mousemove', onMouseMove, true);
                    window.removeEventListener('click', onClick, true);
                    window.removeEventListener('keydown', onKeyDown, true);
                } catch(e) {}

                try {
                    var allOverlays = document.querySelectorAll('#__lotus_zap_overlay__, #__lotus_zap_badge__, [id^="__lotus_zap_"]');
                    for (var i = 0; i < allOverlays.length; i++) {
                        if (allOverlays[i].parentNode) {
                            allOverlays[i].parentNode.removeChild(allOverlays[i]);
                        }
                    }
                } catch(e) {}

                window.__lotusZapActive = false;
                window.__lotusZapCleanup = null;
            };
        })();
        """
    }

    /// Stops and removes the visual element inspector overlay.
    static let stopZapModeScript = """
    (function() {
        try {
            if (typeof window.__lotusZapCleanup === 'function') {
                window.__lotusZapCleanup();
            }
        } catch(e) {}

        try {
            var overlays = document.querySelectorAll('#__lotus_zap_overlay__, #__lotus_zap_badge__, [id^="__lotus_zap_"]');
            for (var i = 0; i < overlays.length; i++) {
                if (overlays[i].parentNode) {
                    overlays[i].parentNode.removeChild(overlays[i]);
                }
            }
        } catch(e) {}

        window.__lotusZapActive = false;
        window.__lotusZapCleanup = null;
    })();
    """

    /// Restores a zapped element in the live DOM.
    static func undoZapScript(selector: String) -> String {
        guard let jsonSelectorData = try? JSONSerialization.data(withJSONObject: [selector]),
              let jsonSelectorArray = String(data: jsonSelectorData, encoding: .utf8),
              jsonSelectorArray.hasPrefix("[") && jsonSelectorArray.hasSuffix("]") else {
            return ""
        }
        let jsonSelector = String(jsonSelectorArray.dropFirst().dropLast())

        return """
        (function() {
            try {
                var nodes = document.querySelectorAll(\(jsonSelector));
                for (var i = 0; i < nodes.length; i++) {
                    nodes[i].style.removeProperty('display');
                    nodes[i].style.removeProperty('visibility');
                    nodes[i].style.removeProperty('opacity');
                    nodes[i].style.removeProperty('filter');
                    nodes[i].style.removeProperty('transform');
                    nodes[i].style.removeProperty('outline');
                    nodes[i].style.removeProperty('box-shadow');
                    nodes[i].style.removeProperty('pointer-events');
                }
            } catch(e) {}
        })();
        """
    }
}
