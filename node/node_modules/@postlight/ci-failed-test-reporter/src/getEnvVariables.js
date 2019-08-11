const dotenv = require('dotenv');
dotenv.config();

const getPrNumber = () => {
  if (process.env.CIFTR_PR_NUMBER) {
    return;
  }

  if (process.env.TRAVIS && process.env.TRAVIS_PULL_REQUEST) {
    return process.env.TRAVIS_PULL_REQUEST;
  }

  if (process.env.CIRCLECI && process.env.CIRCLE_PULL_REQUEST) {
    const splitUrl = process.env.CIRCLE_PULL_REQUEST.split('/');
    const prNumber = splitUrl[splitUrl.length - 1];
    return prNumber;
  }
};

const getUsername = () => {
  if (process.env.CIFTR_PR_USERNAME) {
    return;
  }

  if (process.env.TRAVIS && process.env.TRAVIS_PULL_REQUEST) {
    return process.env.TRAVIS_PULL_REQUEST_SLUG.split('/')[0];
  }

  if (process.env.CIRCLECI && process.env.CIRCLE_PULL_REQUEST) {
    return process.env.CIRCLE_PROJECT_USERNAME;
  }
};

const getRepoName = () => {
  if (process.env.CIFTR_PR_REPONAME) {
    return;
  }

  if (process.env.TRAVIS && process.env.TRAVIS_PULL_REQUEST) {
    return process.env.TRAVIS_PULL_REQUEST_SLUG.split('/')[1];
  }

  if (process.env.CIRCLECI && process.env.CIRCLE_PULL_REQUEST) {
    return process.env.CIRCLE_PROJECT_REPONAME;
  }
};

const getApiKey = () => process.env.CIFTR_GITHUB_API_KEY;

const getEnvVariables = () => ({
  repoName: getRepoName(),
  username: getUsername(),
  prNumber: getPrNumber(),
  apiKey: getApiKey()
});

module.exports = getEnvVariables;
