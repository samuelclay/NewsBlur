#!/usr/bin/env node
/* eslint-disable no-multi-str */
/* eslint-disable no-console */

const ciftr = require('./src/index.js');

const [, , filepath] = process.argv;

if (!filepath) {
  console.log(
    '\n\
ci-test-failure-reporter\n\n\
    The CI Test Failure Reporter comments a nicely formatted test report on your GitHub PR. \n\n\
Usage:\n\
\n\
    ci-test-failure-reporter [path-to-json-file]\n\
\n\
'
  );
} else {
  try {
    ciftr.comment(process.cwd() + `${filepath}`).then(testReport => {
      console.log(
        `\n\
  ci-test-failure-reporter\n\n\
  The following comment was successfully posted to your GitHub PR: \n\n\
      ${testReport}
  \n\
  `
      );
    });
  } catch (err) {
    console.error(`ERROR: ${err}`);
  }
}
