/** @type {import('jest').Config} */
module.exports = {
  rootDir: '.',
  moduleFileExtensions: ['js', 'json', 'ts'],
  testEnvironment: 'node',
  testRegex: '.*\\.e2e-spec\\.ts$',
  transform: {
    '^.+\\.ts$': [
      'ts-jest',
      {
        tsconfig: 'tsconfig.e2e.json',
        isolatedModules: true,
        diagnostics: { warnOnly: true },
      },
    ],
  },
  moduleNameMapper: {
    '^src/(.*)$': '<rootDir>/src/$1',
  },
};
