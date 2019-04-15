const fs = require('fs');

const jsonToResultsObject = require('./jsonToResultsObject');

const testOrTests = numberOfTests => (numberOfTests === 1 ? 'test' : 'tests');

const getTestReport = filepath => {
  try {
    const file = fs.readFileSync(filepath);
    const testReportJson = JSON.parse(file);
    const testReport = jsonToResultsObject(testReportJson);
    const { failedTests } = testReport;
    const numFailedTests = failedTests.length;
    if (numFailedTests === 0) {
      return '';
    }

    const failureReportMsg = `
<details>
<summary>
<b>${numFailedTests} failed ${testOrTests(numFailedTests)} 😱</b>
</summary>

---
${failedTests
  .map(
    ({ fullName, failureMessages }) =>
      `
**${fullName}**
  <details>
  <summary>
    See what went wrong
  </summary>

\`\`\`bash
${
  Array.isArray(failureMessages) ? failureMessages.join('\\n') : failureMessages
}
\`\`\`

---
  </details>

---
  `
  )
  .join('\n\n')}
</details>
`;
    return failureReportMsg;
  } catch (e) {
    // eslint-disable-next-line no-console
    console.log('Error generating test report', e);
    return '';
  }
};

module.exports = getTestReport;
