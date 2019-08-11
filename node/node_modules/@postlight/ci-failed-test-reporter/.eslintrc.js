module.exports = {
  parser: '@typescript-eslint/parser',
  plugins: ['@typescript-eslint'],
  extends: ['prettier', 'prettier/@typescript-eslint', 'eslint:recommended'],
  parserOptions: {
    ecmaVersion: 6,
    sourceType: 'module'
  },
  env: { jest: true, browser: true, node: true },
  rules: { 'no-console': 'warn' }
};
