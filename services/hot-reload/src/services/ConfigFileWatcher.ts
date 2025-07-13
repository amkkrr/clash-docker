import chokidar from 'chokidar';
import { EventEmitter } from 'events';
import { readFileSync } from 'fs';
import { parse } from 'dotenv';
import { ConfigChange } from '../types';
import { Logger } from '../utils/logger';
import { metricsCollector } from '../utils/metrics';

export class ConfigFileWatcher extends EventEmitter {
  private watcher!: chokidar.FSWatcher;
  private watchPaths: string[];
  private lastChangeTime: Map<string, number> = new Map();
  private configCache: Map<string, Record<string, string>> = new Map();
  private debounceTime: number = 2000; // 2秒防抖
  private logger: Logger;
  
  constructor(watchPaths: string[], debounceTime: number = 2000) {
    super();
    this.watchPaths = watchPaths;
    this.debounceTime = debounceTime;
    this.logger = new Logger('ConfigFileWatcher');
    this.initializeWatcher();
  }
  
  private initializeWatcher(): void {
    this.watcher = chokidar.watch(this.watchPaths, {
      ignored: /(^|[\/\\])\../, // 忽略隐藏文件
      persistent: true,
      ignoreInitial: false,
      awaitWriteFinish: {
        stabilityThreshold: 1000,
        pollInterval: 100
      }
    });
    
    // 设置事件监听器
    this.watcher
      .on('add', (path) => this.handleFileChange(path, 'added'))
      .on('change', (path) => this.handleFileChange(path, 'changed'))
      .on('unlink', (path) => this.handleFileChange(path, 'unlinked'))
      .on('error', (error) => {
        this.logger.error('Watcher error:', error);
        metricsCollector.recordError('watcher_error', 'config_file_watcher');
        this.emit('error', error);
      })
      .on('ready', () => {
        this.logger.info(`Watching ${this.watchPaths.length} paths for changes`);
      });
  }
  
  private async handleFileChange(filePath: string, changeType: string): Promise<void> {
    const now = Date.now();
    const lastTime = this.lastChangeTime.get(filePath) || 0;
    
    // 防抖动 - 避免频繁触发
    if (now - lastTime < this.debounceTime) {
      this.logger.debug(`Debouncing change for ${filePath}`);
      return;
    }
    
    this.lastChangeTime.set(filePath, now);
    this.logger.info(`Detected ${changeType} change in ${filePath}`);
    
    // 记录文件监控事件指标
    metricsCollector.recordFileWatcherEvent(changeType, filePath);
    
    try {
      const change = await this.analyzeChange(filePath, changeType as ConfigChange['changeType']);
      this.emit('configChange', change);
    } catch (error) {
      this.logger.error(`Error analyzing change in ${filePath}:`, error);
      metricsCollector.recordError('analyze_change_error', 'config_file_watcher');
      this.emit('error', error);
    }
  }
  
  private async analyzeChange(filePath: string, changeType: ConfigChange['changeType']): Promise<ConfigChange> {
    const change: ConfigChange = {
      timestamp: new Date().toISOString(),
      filePath,
      changeType,
      severity: 'minor',
      affectedServices: []
    };
    
    if (filePath.endsWith('.env')) {
      return this.analyzeEnvChange(filePath, changeType, change);
    } else if (filePath.includes('rules/')) {
      return this.analyzeRuleChange(filePath, changeType, change);
    } else if (filePath.includes('templates/')) {
      return this.analyzeTemplateChange(filePath, changeType, change);
    } else if (filePath.endsWith('.yaml') || filePath.endsWith('.yml')) {
      return this.analyzeYamlChange(filePath, changeType, change);
    }
    
    return change;
  }
  
  private analyzeEnvChange(filePath: string, changeType: ConfigChange['changeType'], change: ConfigChange): ConfigChange {
    const oldConfig = this.configCache.get(filePath) || {};
    let newConfig: Record<string, string> = {};
    
    if (changeType !== 'unlinked') {
      try {
        const envContent = readFileSync(filePath, 'utf8');
        newConfig = parse(envContent);
        this.configCache.set(filePath, newConfig);
      } catch (error) {
        this.logger.warn(`Failed to read ${filePath}:`, error);
        return change;
      }
    } else {
      this.configCache.delete(filePath);
    }
    
    // 分析具体变化
    const { severity, affectedServices } = this.calculateChangeImpact(oldConfig, newConfig);
    
    // 记录配置变更指标
    const fileType = filePath.split('.').pop() || 'unknown';
    metricsCollector.recordConfigChange(severity, fileType, changeType);
    
    return {
      ...change,
      severity,
      affectedServices,
      oldConfig,
      newConfig
    };
  }
  
  private calculateChangeImpact(oldConfig: Record<string, string>, newConfig: Record<string, string>): { severity: ConfigChange['severity'], affectedServices: string[] } {
    const severityRules = {
      critical: ['CLASH_SECRET', 'CLASH_EXTERNAL_CONTROLLER', 'COMPOSE_PROJECT_NAME'],
      moderate: ['JP_HYSTERIA2_SERVER', 'SJC_HYSTERIA2_SERVER', 'CLASH_HTTP_PORT', 'CLASH_SOCKS_PORT'],
      minor: ['CLASH_LOG_LEVEL', 'CLASH_IPV6', 'CLASH_ALLOW_LAN']
    };
    
    const changedKeys = this.getChangedKeys(oldConfig, newConfig);
    let severity: ConfigChange['severity'] = 'minor';
    const affectedServices = new Set<string>();
    
    for (const key of changedKeys) {
      // 检查严重程度
      for (const [level, rules] of Object.entries(severityRules)) {
        if (rules.some(rule => 
          rule.includes('*') ? key.endsWith(rule.slice(1)) : rule === key
        )) {
          if (level === 'critical') {
            severity = 'critical';
          } else if (level === 'moderate' && severity !== 'critical') {
            severity = 'moderate';
          }
        }
      }
      
      // 确定受影响的服务
      if (key.includes('CLASH')) affectedServices.add('clash');
      if (key.includes('NGINX')) affectedServices.add('nginx');
      if (['HYSTERIA2', 'SHADOWSOCKS', 'VMESS', 'VLESS'].some(proto => key.includes(proto))) {
        affectedServices.add('clash');
      }
    }
    
    return {
      severity,
      affectedServices: Array.from(affectedServices).length > 0 ? Array.from(affectedServices) : ['clash']
    };
  }
  
  private getChangedKeys(oldConfig: Record<string, string>, newConfig: Record<string, string>): string[] {
    const allKeys = new Set([...Object.keys(oldConfig), ...Object.keys(newConfig)]);
    const changedKeys: string[] = [];
    
    for (const key of allKeys) {
      if (oldConfig[key] !== newConfig[key]) {
        changedKeys.push(key);
      }
    }
    
    return changedKeys;
  }
  
  private analyzeRuleChange(_filePath: string, _changeType: ConfigChange['changeType'], change: ConfigChange): ConfigChange {
    return {
      ...change,
      severity: 'moderate',
      affectedServices: ['clash']
    };
  }
  
  private analyzeTemplateChange(_filePath: string, _changeType: ConfigChange['changeType'], change: ConfigChange): ConfigChange {
    return {
      ...change,
      severity: 'minor',
      affectedServices: ['clash']
    };
  }
  
  private analyzeYamlChange(filePath: string, _changeType: ConfigChange['changeType'], change: ConfigChange): ConfigChange {
    // 如果是主配置文件 config.yaml
    if (filePath.includes('config.yaml')) {
      return {
        ...change,
        severity: 'critical',
        affectedServices: ['clash']
      };
    }
    
    return {
      ...change,
      severity: 'moderate',
      affectedServices: ['clash']
    };
  }
  
  public getWatchedPaths(): string[] {
    return [...this.watchPaths];
  }
  
  public getConfigCache(): Map<string, Record<string, string>> {
    return new Map(this.configCache);
  }
  
  public stop(): void {
    this.logger.info('Stopping config file watcher');
    if (this.watcher) {
      this.watcher.close();
    }
  }
}