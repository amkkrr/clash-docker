// 配置变更事件类型
export interface ConfigChange {
  timestamp: string;
  filePath: string;
  changeType: 'added' | 'changed' | 'unlinked';
  severity: 'critical' | 'moderate' | 'minor';
  affectedServices: string[];
  oldConfig?: Record<string, string>;
  newConfig?: Record<string, string>;
}

// 服务重启结果
export interface RestartResult {
  success: boolean;
  service: string;
  duration: number;
  error?: string;
}

// 系统状态
export interface SystemStatus {
  status: 'stable' | 'updating' | 'restarting' | 'error';
  services: {
    [serviceName: string]: {
      status: 'running' | 'stopped' | 'restarting' | 'error';
      health: 'healthy' | 'unhealthy' | 'unknown';
      uptime: number;
    };
  };
  lastUpdate: string;
}

// WebSocket 消息
export interface WebSocketMessage {
  type: string;
  timestamp: string;
  data: any;
}

// 配置差异
export interface ConfigDiff {
  key: string;
  changeType: 'added' | 'removed' | 'modified';
  oldValue?: string;
  newValue?: string;
  severity: 'critical' | 'moderate' | 'minor';
}

// 配置分析结果
export interface ChangeAnalysis {
  severity: 'critical' | 'moderate' | 'minor';
  added: string[];
  removed: string[];
  modified: string[];
  affectedServices: string[];
  configDiff: ConfigDiff[];
}

// 验证结果
export interface ValidationResult {
  isValid: boolean;
  errors: ValidationError[];
  warnings?: ValidationError[];
}

export interface ValidationError {
  path: string;
  message: string;
  value?: any;
}

// 服务依赖关系
export interface ServiceDependency {
  [serviceName: string]: string[];
}

// 重启阶段
export interface RestartPhase {
  phase: number;
  services: string[];
  parallel: boolean;
  estimatedDuration: number;
}