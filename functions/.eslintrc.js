//===================================================
// NUBIFY FIREBASE FUNCTIONS ESLINT
//===================================================

module.exports = {
  root: true,

  env: {
    es6: true,
    node: true,
  },

  parserOptions: {
    ecmaVersion: 2022,
  },

  extends: [
    "eslint:recommended",
    "google",
  ],

  rules: {
    //===================================================
    // KEEP REAL JAVASCRIPT ERROR CHECKING
    //===================================================

    "no-undef": "error",
    "no-unused-vars": "error",

    //===================================================
    // NUBIFY FORMATTING
    //===================================================

    "indent": "off",
    "spaced-comment": "off",
    "require-jsdoc": "off",
    "valid-jsdoc": "off",
    "max-len": "off",
    "operator-linebreak": "off",
    "quotes": "off",
    "no-empty": "off",
    "eol-last": "off",
  },
};