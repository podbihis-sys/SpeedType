module.exports = {
  root: true,
  env: {
    es2020: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "google",
    "plugin:@typescript-eslint/recommended",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    ecmaVersion: 2020,
    sourceType: "module",
    project: ["tsconfig.json"],
  },
  ignorePatterns: [
    "/lib/**/*", // Ignore built files.
    "/generated/**/*",
    "node_modules/**/*",
  ],
  plugins: [
    "@typescript-eslint",
  ],
  rules: {
    "quotes": ["error", "double"],
    "import/no-unresolved": 0,
    "indent": ["error", 2],
    "object-curly-spacing": ["error", "never"],
    "max-len": ["error", {code: 100, ignoreUrls: true}],
    "require-jsdoc": 0,
    "valid-jsdoc": 0,
    "new-cap": 0,
    "@typescript-eslint/no-explicit-any": "warn",
    "@typescript-eslint/no-unused-vars": [
      "warn",
      {argsIgnorePattern: "^_"},
    ],
  },
};
