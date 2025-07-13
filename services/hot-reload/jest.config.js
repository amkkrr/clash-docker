module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src', '<rootDir>/tests'],
  testMatch: ['**/__tests__/**/*.ts', '**/?(*.)+(spec|test).ts'],
  transform: {
    '^.+\\.ts$': 'ts-jest',
  },
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/app.ts',
    '!src/types/**',
    '!src/**/*.interface.ts'
  ],
  coverageDirectory: 'coverage',
  coverageReporters: [
    'text',
    'text-summary', 
    'lcov',
    'html',
    'json',
    'cobertura'
  ],
  coverageThreshold: {
    global: {
      branches: 30,
      functions: 35,
      lines: 35,
      statements: 35
    },
    './src/services/': {
      branches: 15,
      functions: 25,
      lines: 30,
      statements: 30
    },
    './src/utils/': {
      branches: 20,
      functions: 25,
      lines: 35,
      statements: 35
    }
  },
  // 测试超时配置
  testTimeout: 30000,
  // 详细输出
  verbose: true,
  // 显示覆盖率摘要
  coveragePathIgnorePatterns: [
    '/node_modules/',
    '/dist/',
    '/coverage/',
    '/.git/'
  ],
  // 设置模块目录
  moduleDirectories: ['node_modules', '<rootDir>/src'],
  // 清理之前的覆盖率数据
  clearMocks: true,
  // 收集覆盖率信息
  collectCoverage: false, // 默认关闭，通过命令行参数控制
  // 最大工作进程数
  maxWorkers: '50%'
};