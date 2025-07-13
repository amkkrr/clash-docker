module.exports = {
  env: {
    es2021: true,
    node: true,
    jest: true, // 添加 Jest 环境支持
  },
  extends: [
    'eslint:recommended',
    'prettier',
  ],
  parser: '@typescript-eslint/parser',
  parserOptions: {
    ecmaVersion: 'latest',
    sourceType: 'module',
  },
  plugins: ['@typescript-eslint', 'prettier'],
  rules: {
    'prettier/prettier': 'error',
    '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
    '@typescript-eslint/no-explicit-any': 'warn',
    'prefer-const': 'error',
    'no-var': 'error',
    'no-undef': 'off', // 关闭 no-undef，因为 TypeScript 会处理
  },
  ignorePatterns: ['dist/', 'node_modules/', 'coverage/'],
};