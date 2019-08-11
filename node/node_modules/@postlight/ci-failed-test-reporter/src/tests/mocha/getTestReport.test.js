const stripAnsi = require('strip-ansi');
const path = require('path');
const assert = require('assert');

const getTestReport = require('../../getTestReport');

describe('basic test', () => {
  it('Generates a test report', () => {
    // don't test the whitespace formatting, just the content
    const testReport = stripAnsi(
      getTestReport(path.join(__dirname, '../', '/test-output.test.json'))
    ).replace(/\s/g, '');
    assert.equal(testReport.startsWith('<details>'), true);
  });
});
