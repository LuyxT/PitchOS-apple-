module.exports = {
  root: true,
  parserOptions: {
    project: ['./tsconfig.json'],
    tsconfigRootDir: __dirname,
  },
  env: {
    node: true,
    es2022: true,
  },
  extends: ['eslint:recommended', 'plugin:import/recommended', 'prettier'],
  ignorePatterns: ['dist', 'node_modules'],
  rules: {
    'import/no-unresolved': 'off',
  },
};
