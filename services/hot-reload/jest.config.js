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
      branches: 70,
      functions: 75,
      lines: 80,
      statements: 80
    },
    './src/services/': {
      branches: 75,
      functions: 80,
      lines: 85,
      statements: 85
    },
    './src/utils/': {
      branches: 80,
      functions: 85,
      lines: 90,
      statements: 90
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