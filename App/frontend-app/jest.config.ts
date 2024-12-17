import type { Config } from '@jest/types'

const config: Config.InitialOptions = {
  verbose: true,

  preset: 'ts-jest',
  //testEnvironment: 'jsdom',  // For React DOM testing
  testEnvironment: 'jest-environment-jsdom',
  testEnvironmentOptions: {
    customExportConditions: ['']
  },
  moduleNameMapper: {
    '\\.(css|less|scss)$': 'identity-obj-proxy', // For mocking static file imports
    '^react-markdown$': '<rootDir>/__mocks__/react-markdown.tsx',
    '^dompurify$': '<rootDir>/__mocks__/dompurify.js', // Point to the mock
    '\\.(jpg|jpeg|png|gif|svg)$': '<rootDir>/__mocks__/fileMock.ts',
    "^i18next$": "<rootDir>/__mocks__/i18n.ts",

  },
  setupFilesAfterEnv: ['<rootDir>/src/test/setupTests.ts'], // For setting up testing environment like jest-dom
  transform: {
    '^.+\\.ts(x)?$': ['ts-jest',
      {
        diagnostics: {
          ignoreCodes: [1343]
        },
        astTransformers: {
          before: [
            {
              path: 'node_modules/ts-jest-mock-import-meta',  // or, alternatively, 'ts-jest-mock-import-meta' directly, without node_modules.
              options: { metaObjectReplacement: { env : { 'VITE_API_ENDPOINT' : 'https://mock-api-endpoint.com' }} }
            }
          ]
        }
      }

    ],  // For TypeScript files
    '^.+\\.js$': 'babel-jest',  // For JavaScript files if you have Babel 
  },

  setupFiles: ['<rootDir>/jest.polyfills.js'],
  collectCoverage: true,
  collectCoverageFrom: ['src/**/*.{ts,tsx}'],  // Adjust the path as needed
  //coverageReporters: ['json', 'lcov', 'text', 'clover'],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80,
    },
  },

  coveragePathIgnorePatterns: [
    '<rootDir>/node_modules/', // Ignore node_modules
    '<rootDir>/__mocks__/', // Ignore mocks
    '<rootDir>/src/state/',
    '<rootDir>/src/api/',
    '<rootDir>/src/mocks/',
    '<rootDir>/src/test/',
    '<rootDir>/src/assets/',
    '<rootDir>/src/utils/',
    '<rootDir>/src/types/',

    '<rootDir>/src/App.tsx',
    '<rootDir>/src/AppContext.tsx',
    '<rootDir>/src/AppRoutes.tsx',
    '<rootDir>/src/main.tsx',
    '<rootDir>/src/styles.tsx',
    '<rootDir>/src/vite-env.d.ts',
    '<rootDir>/src/components/uploadButton/uploadButton2.tsx',
    '<rootDir>/src/components/searchResult/old.tsx',
    '<rootDir>/src/components/chat/modelSwitch.tsx',
  ],
}

export default config
