// NewsBlur Archive Extension - Content Script
// Handles content extraction from web pages

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

    // Use best available title and description
    const bestTitle = ogTitle || title;
    const bestDescription = ogDescription || description;

    return {
        title: bestTitle,
        content: textContent,
        contentLength: textContent.length,
        excerpt: bestDescription || textContent.substring(0, 300)
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

// Log that the content script is loaded
console.log('NewsBlur Archive: Content script loaded');
