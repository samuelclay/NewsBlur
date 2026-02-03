/**
 * Shared selector parsing and validation library
 * Supports CSS and XPath selectors with security validation
 */

// Allowlist of safe XPath axes (standard DOM traversal)
const ALLOWED_XPATH_AXES = [
  'ancestor', 'ancestor-or-self', 'attribute', 'child', 'descendant',
  'descendant-or-self', 'following', 'following-sibling', 'namespace',
  'parent', 'preceding', 'preceding-sibling', 'self'
];

// Allowlist of safe XPath functions (node selection and string ops)
const ALLOWED_XPATH_FUNCTIONS = [
  'text', 'contains', 'starts-with', 'normalize-space', 'string-length',
  'concat', 'substring', 'substring-before', 'substring-after', 'translate',
  'not', 'true', 'false', 'boolean', 'string', 'number', 'sum', 'floor',
  'ceiling', 'round', 'count', 'name', 'local-name', 'namespace-uri',
  'last', 'position', 'id', 'lang', 'comment', 'processing-instruction', 'node'
];

/**
 * Parse and validate selector
 * @param {string} selector - CSS or XPath selector
 * @returns {{type: 'css'|'xpath', selector: string}}
 * @throws {Error} If selector fails validation
 */
export function parseSelector(selector) {
  if (!selector || typeof selector !== 'string') {
    throw new Error('Selector must be a non-empty string');
  }

  // Detect XPath selectors
  if (selector.startsWith('/') || selector.startsWith('(//')) {
    validateXPath(selector);
    return { type: 'xpath', selector };
  }

  // CSS selector
  validateCSS(selector);
  return { type: 'css', selector };
}

/**
 * Validate XPath selector using allowlist approach
 * @param {string} xpath - XPath expression to validate
 * @throws {Error} If XPath fails validation
 */
function validateXPath(xpath) {
  // Length limit to prevent DoS
  if (xpath.length > 1000) {
    throw new Error('XPath selector too long (max 1000 characters)');
  }

  // Complexity limits
  const predicateCount = (xpath.match(/\[/g) || []).length;
  if (predicateCount > 10) {
    throw new Error('XPath too complex: max 10 predicates allowed');
  }

  const nestingDepth = Math.max(...xpath.split('').reduce((depths, char, i) => {
    if (char === '[') depths.push((depths[depths.length - 1] || 0) + 1);
    else if (char === ']') depths.push(Math.max(0, (depths[depths.length - 1] || 0) - 1));
    else if (depths.length) depths.push(depths[depths.length - 1]);
    else depths.push(0);
    return depths;
  }, []));
  if (nestingDepth > 5) {
    throw new Error('XPath too deeply nested: max 5 levels allowed');
  }

  // Extract and validate function calls using allowlist
  const functionPattern = /([a-z][a-z0-9-]*)\s*\(/gi;
  let match;
  while ((match = functionPattern.exec(xpath)) !== null) {
    const funcName = match[1].toLowerCase();
    if (!ALLOWED_XPATH_FUNCTIONS.includes(funcName)) {
      throw new Error(`XPath function not allowed: ${funcName}. Allowed: ${ALLOWED_XPATH_FUNCTIONS.join(', ')}`);
    }
  }

  // Validate axes using allowlist
  const axisPattern = /([a-z][a-z-]*)::/gi;
  while ((match = axisPattern.exec(xpath)) !== null) {
    const axisName = match[1].toLowerCase();
    if (!ALLOWED_XPATH_AXES.includes(axisName)) {
      throw new Error(`XPath axis not allowed: ${axisName}. Allowed: ${ALLOWED_XPATH_AXES.join(', ')}`);
    }
  }

  // Block obvious non-XPath content (URLs, scripts, HTML)
  if (/^https?:\/\//i.test(xpath)) {
    throw new Error('XPath cannot be a URL');
  }
  if (/<[a-z]/i.test(xpath)) {
    throw new Error('XPath cannot contain HTML tags');
  }
}

/**
 * Validate CSS selector for security
 * @param {string} css - CSS selector to validate
 * @throws {Error} If CSS selector fails validation
 */
function validateCSS(css) {
  // Length limit to prevent DoS
  if (css.length > 500) {
    throw new Error('CSS selector too long (max 500 characters)');
  }

  // Complexity limits
  const selectorParts = css.split(/\s*,\s*/);
  if (selectorParts.length > 10) {
    throw new Error('CSS selector too complex: max 10 comma-separated selectors');
  }

  // Check nesting depth (combinators indicate depth)
  const maxDepth = Math.max(...selectorParts.map(part =>
    (part.match(/[\s>+~]/g) || []).length
  ));
  if (maxDepth > 10) {
    throw new Error('CSS selector too deeply nested: max 10 levels');
  }

  // Block non-CSS content
  if (/^https?:\/\//i.test(css)) {
    throw new Error('CSS selector cannot be a URL');
  }
  if (/<[a-z]/i.test(css)) {
    throw new Error('CSS selector cannot contain HTML tags');
  }
  // Block url() which could be used for data exfiltration in some contexts
  if (/url\s*\(/i.test(css)) {
    throw new Error('CSS selector cannot contain url()');
  }
}

/**
 * Wait for element based on selector type
 * @param {Object} page - Puppeteer page instance
 * @param {{type: string, selector: string}} parsed - Parsed selector
 * @param {Object} options - Wait options (visible, timeout)
 * @returns {Promise<void>}
 */
export async function waitForElement(page, parsed, options = {}) {
  const defaultOptions = {
    visible: true,
    timeout: 5000,
    ...options
  };

  if (parsed.type === 'xpath') {
    // Use locator API for XPath (Puppeteer v24+)
    const locator = page.locator(`::-p-xpath(${parsed.selector})`);
    // setVisibility and setTimeout are the locator options
    await locator
      .setVisibility(defaultOptions.visible ? 'visible' : null)
      .setTimeout(defaultOptions.timeout)
      .wait();
  } else {
    await page.waitForSelector(parsed.selector, defaultOptions);
  }
}

/**
 * Click element based on selector type
 * @param {Object} page - Puppeteer page instance
 * @param {{type: string, selector: string}} parsed - Parsed selector
 * @returns {Promise<void>}
 */
export async function clickElement(page, parsed) {
  if (parsed.type === 'xpath') {
    // Use locator API for XPath (Puppeteer v24+)
    const locator = page.locator(`::-p-xpath(${parsed.selector})`);
    await locator.click();
  } else {
    await page.click(parsed.selector);
  }
}

/**
 * Type into element based on selector type
 * @param {Object} page - Puppeteer page instance
 * @param {{type: string, selector: string}} parsed - Parsed selector
 * @param {string} value - Text to type
 * @param {Object} options - Type options (delay, clear)
 * @returns {Promise<void>}
 */
export async function typeIntoElement(page, parsed, value, options = {}) {
  if (parsed.type === 'xpath') {
    // Use locator API for XPath (Puppeteer v24+)
    const locator = page.locator(`::-p-xpath(${parsed.selector})`);

    // Clear if requested
    if (options.clear) {
      await locator.fill('');
    }

    await locator.fill(value);
  } else {
    // CSS selector
    if (options.clear) {
      await page.$eval(parsed.selector, el => el.value = '');
    }

    await page.type(parsed.selector, value, { delay: options.delay || 0 });
  }
}

/**
 * Get element handle based on selector type
 * @param {Object} page - Puppeteer page instance
 * @param {{type: string, selector: string}} parsed - Parsed selector
 * @returns {Promise<ElementHandle|null>}
 */
export async function getElement(page, parsed) {
  if (parsed.type === 'xpath') {
    // For XPath, use page.evaluate with XPath evaluation
    // This returns the first matching element
    const element = await page.evaluateHandle((xpath) => {
      const result = document.evaluate(
        xpath,
        document,
        null,
        XPathResult.FIRST_ORDERED_NODE_TYPE,
        null
      );
      return result.singleNodeValue;
    }, parsed.selector);

    // Convert JSHandle to ElementHandle
    const elementHandle = element.asElement();
    return elementHandle;
  } else {
    return await page.$(parsed.selector);
  }
}

/**
 * Get enhanced error message for selector failures
 * @param {Error} error - Original error
 * @param {string} selector - Selector that failed
 * @returns {Error} Enhanced error with troubleshooting tips
 */
export function enhanceError(error, selector) {
  if (error.message.includes('waiting for selector') ||
      error.message.includes('waiting for XPath') ||
      error.message.includes('No node found')) {
    error.message += '\n\nTroubleshooting:\n' +
      '1. Use snapshot.js to find correct selector: node snapshot.js --url <url>\n' +
      '2. Try XPath selector: //button[text()="Click"] or //button[contains(text(),"Click")]\n' +
      '3. Check element is visible on page (not display:none or hidden)\n' +
      '4. Increase --timeout value: --timeout 10000\n' +
      '5. Change wait strategy: --wait-until load or --wait-until domcontentloaded';
  }
  return error;
}
