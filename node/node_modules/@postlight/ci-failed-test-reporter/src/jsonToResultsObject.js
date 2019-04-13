const isMocha = json => !!json.stats;
const isJest = json => !!json.testResults;

const jsonToResultsObject = json => {
  if (isMocha(json)) {
    const { failures } = json;
    const failedTests = failures.map(failure => ({
      fullName: failure.fullTitle,
      failureMessages: failure.err.stack
    }));

    return {
      ...json,
      failedTests
    };
  }

  if (isJest(json)) {
    const { testResults } = json;
    const failedTests = testResults
      .map(({ assertionResults }) =>
        assertionResults.filter(({ status }) => status !== 'passed')
      )
      .reduce((acc, arr) => acc.concat(arr));
    return {
      ...json,
      failedTests
    };
  }

  throw 'JSON test report not in a recognized format';
};

module.exports = jsonToResultsObject;
