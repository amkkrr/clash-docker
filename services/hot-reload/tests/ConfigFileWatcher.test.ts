import { ConfigFileWatcher } from '../src/services/ConfigFileWatcher';
import { ConfigChange } from '../src/types';
import { promises as fs } from 'fs';
import path from 'path';
import { tmpdir } from 'os';

describe('ConfigFileWatcher', () => {
  let tempDir: string;
  let watcher: ConfigFileWatcher;
  let testEnvFile: string;

  beforeEach(async () => {
    // 创建临时目录
    tempDir = await fs.mkdtemp(path.join(tmpdir(), 'config-test-'));
    testEnvFile = path.join(tempDir, '.env');

    // 创建测试配置文件
    await fs.writeFile(testEnvFile, 'TEST_VAR=initial_value\nCLASH_SECRET=test123\n');

    // 初始化监控器
    watcher = new ConfigFileWatcher([testEnvFile], 500); // 较短的防抖时间用于测试
  });

  afterEach(async () => {
    // 清理
    if (watcher) {
      watcher.stop();
    }
    await fs.rm(tempDir, { recursive: true, force: true });
  });

  it('should detect file changes', (done) => {
    watcher.on('configChange', (change: ConfigChange) => {
      expect(change.filePath).toBe(testEnvFile);
      expect(change.changeType).toBe('changed');
      expect(change.severity).toBeDefined();
      done();
    });

    // 等待监控器初始化
    setTimeout(() => {
      fs.writeFile(testEnvFile, 'TEST_VAR=new_value\nCLASH_SECRET=test123\n');
    }, 1000);
  });

  it('should analyze severity correctly', (done) => {
    watcher.on('configChange', (change: ConfigChange) => {
      if (change.changeType === 'changed') {
        // CLASH_SECRET变化应该是critical级别
        expect(change.severity).toBe('critical');
        expect(change.affectedServices).toContain('clash');
        done();
      }
    });

    setTimeout(() => {
      fs.writeFile(testEnvFile, 'TEST_VAR=initial_value\nCLASH_SECRET=new_secret\n');
    }, 1000);
  });

  it('should provide config cache', () => {
    const cache = watcher.getConfigCache();
    expect(cache).toBeInstanceOf(Map);
  });

  it('should provide watched paths', () => {
    const paths = watcher.getWatchedPaths();
    expect(paths).toContain(testEnvFile);
  });
});
