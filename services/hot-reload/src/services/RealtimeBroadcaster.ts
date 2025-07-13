import { Server as SocketIOServer } from 'socket.io';
import { Server as HttpServer } from 'http';
import { EventEmitter } from 'events';
import { ConfigChange, RestartResult, SystemStatus, WebSocketMessage } from '../types';
import { Logger } from '../utils/logger';
import { metricsCollector } from '../utils/metrics';

export class RealtimeBroadcaster extends EventEmitter {
  private io: SocketIOServer;
  private connectedClients: Set<string> = new Set();
  private systemStatus: SystemStatus;
  private logger: Logger;
  
  constructor(httpServer: HttpServer) {
    super();
    this.logger = new Logger('RealtimeBroadcaster');
    
    this.io = new SocketIOServer(httpServer, {
      cors: {
        origin: "*", // 在生产环境中应该限制具体域名
        methods: ["GET", "POST"]
      },
      path: '/ws/config-status'
    });
    
    this.systemStatus = {
      status: 'stable',
      services: {},
      lastUpdate: new Date().toISOString()
    };
    
    this.setupSocketHandlers();
  }
  
  private setupSocketHandlers(): void {
    this.io.on('connection', (socket) => {
      this.logger.info(`Client connected: ${socket.id}`);
      this.connectedClients.add(socket.id);
      
      // 更新连接客户端数量指标
      metricsCollector.updateConnectedClients(this.connectedClients.size);
      
      // 发送当前系统状态
      this.sendToClient(socket.id, {
        type: 'status_update',
        timestamp: new Date().toISOString(),
        data: this.systemStatus
      });
      
      // 处理客户端断开连接
      socket.on('disconnect', () => {
        this.logger.info(`Client disconnected: ${socket.id}`);
        this.connectedClients.delete(socket.id);
        
        // 更新连接客户端数量指标
        metricsCollector.updateConnectedClients(this.connectedClients.size);
      });
      
      // 处理客户端心跳
      socket.on('ping', () => {
        socket.emit('pong', { timestamp: new Date().toISOString() });
      });
      
      // 处理获取状态请求
      socket.on('get_status', () => {
        this.sendToClient(socket.id, {
          type: 'status_update',
          timestamp: new Date().toISOString(),
          data: this.systemStatus
        });
      });
      
      // 处理获取服务列表请求
      socket.on('get_services', () => {
        this.sendToClient(socket.id, {
          type: 'services_list',
          timestamp: new Date().toISOString(),
          data: {
            services: Object.keys(this.systemStatus.services)
          }
        });
      });
    });
  }
  
  public broadcastConfigChange(change: ConfigChange): void {
    const message: WebSocketMessage = {
      type: 'config_change',
      timestamp: new Date().toISOString(),
      data: {
        filePath: change.filePath,
        changeType: change.changeType,
        severity: change.severity,
        affectedServices: change.affectedServices,
        hasOldConfig: !!change.oldConfig,
        hasNewConfig: !!change.newConfig
      }
    };
    
    this.broadcastToAll(message);
    this.updateSystemStatus('updating');
    this.logger.info(`Broadcasted config change: ${change.filePath} (${change.severity})`);
  }
  
  public broadcastRestartProgress(service: string, status: string, progress?: number): void {
    const message: WebSocketMessage = {
      type: 'restart_progress',
      timestamp: new Date().toISOString(),
      data: {
        service,
        status, // 'starting', 'stopping', 'healthy', 'failed'
        progress: progress || 0
      }
    };
    
    this.broadcastToAll(message);
    
    // 更新服务状态
    if (!this.systemStatus.services[service]) {
      this.systemStatus.services[service] = {
        status: 'stopped',
        health: 'unknown',
        uptime: 0
      };
    }
    
    switch (status) {
      case 'starting':
        this.systemStatus.services[service].status = 'restarting';
        this.updateSystemStatus('restarting');
        break;
      case 'healthy':
        this.systemStatus.services[service].status = 'running';
        this.systemStatus.services[service].health = 'healthy';
        this.systemStatus.services[service].uptime = Date.now();
        this.checkAndUpdateSystemStatus();
        break;
      case 'failed':
        this.systemStatus.services[service].status = 'error';
        this.systemStatus.services[service].health = 'unhealthy';
        this.updateSystemStatus('error');
        break;
    }
    
    this.logger.debug(`Service ${service} status updated: ${status}`);
  }
  
  public broadcastRestartCompleted(results: RestartResult[]): void {
    const message: WebSocketMessage = {
      type: 'restart_completed',
      timestamp: new Date().toISOString(),
      data: {
        results,
        totalServices: results.length,
        successCount: results.filter(r => r.success).length,
        failedCount: results.filter(r => !r.success).length,
        totalDuration: results.reduce((sum, r) => sum + r.duration, 0)
      }
    };
    
    this.broadcastToAll(message);
    
    // 更新系统状态
    const hasFailures = results.some(r => !r.success);
    this.updateSystemStatus(hasFailures ? 'error' : 'stable');
    
    this.logger.info(`Restart completed: ${results.filter(r => r.success).length}/${results.length} services successful`);
  }
  
  public broadcastSystemHealthUpdate(serviceHealth: { [service: string]: boolean }): void {
    // 更新服务健康状态
    for (const [service, isHealthy] of Object.entries(serviceHealth)) {
      if (!this.systemStatus.services[service]) {
        this.systemStatus.services[service] = {
          status: 'running',
          health: 'unknown',
          uptime: 0
        };
      }
      
      this.systemStatus.services[service].health = isHealthy ? 'healthy' : 'unhealthy';
      this.systemStatus.services[service].status = isHealthy ? 'running' : 'error';
    }
    
    const message: WebSocketMessage = {
      type: 'health_update',
      timestamp: new Date().toISOString(),
      data: {
        services: serviceHealth,
        systemStatus: this.systemStatus.status
      }
    };
    
    this.broadcastToAll(message);
    this.checkAndUpdateSystemStatus();
  }
  
  public broadcastError(error: string, details?: any): void {
    const message: WebSocketMessage = {
      type: 'error',
      timestamp: new Date().toISOString(),
      data: {
        error,
        details
      }
    };
    
    this.broadcastToAll(message);
    this.updateSystemStatus('error');
    this.logger.error(`Broadcasting error: ${error}`);
  }
  
  public broadcastLog(level: string, message: string, context?: string): void {
    const logMessage: WebSocketMessage = {
      type: 'log',
      timestamp: new Date().toISOString(),
      data: {
        level,
        message,
        context
      }
    };
    
    this.broadcastToAll(logMessage);
  }
  
  private sendToClient(clientId: string, message: WebSocketMessage): void {
    this.io.to(clientId).emit('message', message);
  }
  
  private broadcastToAll(message: WebSocketMessage): void {
    this.io.emit('message', message);
    this.logger.debug(`Broadcasting message type: ${message.type} to ${this.connectedClients.size} clients`);
  }
  
  public updateSystemStatus(status: SystemStatus['status']): void {
    this.systemStatus.status = status;
    this.systemStatus.lastUpdate = new Date().toISOString();
    
    // 广播状态更新
    this.broadcastToAll({
      type: 'status_update',
      timestamp: new Date().toISOString(),
      data: this.systemStatus
    });
  }
  
  private checkAndUpdateSystemStatus(): void {
    const services = Object.values(this.systemStatus.services);
    
    if (services.length === 0) {
      this.updateSystemStatus('stable');
      return;
    }
    
    const hasErrors = services.some(s => s.status === 'error' || s.health === 'unhealthy');
    const hasRestarting = services.some(s => s.status === 'restarting');
    
    if (hasErrors) {
      this.updateSystemStatus('error');
    } else if (hasRestarting) {
      this.updateSystemStatus('restarting');
    } else {
      this.updateSystemStatus('stable');
    }
  }
  
  public getConnectedClientsCount(): number {
    return this.connectedClients.size;
  }
  
  public getCurrentSystemStatus(): SystemStatus {
    return { ...this.systemStatus };
  }
  
  public updateServiceStatus(serviceName: string, status: 'running' | 'stopped' | 'restarting' | 'error', health: 'healthy' | 'unhealthy' | 'unknown'): void {
    if (!this.systemStatus.services[serviceName]) {
      this.systemStatus.services[serviceName] = {
        status: 'stopped',
        health: 'unknown',
        uptime: 0
      };
    }
    
    this.systemStatus.services[serviceName].status = status;
    this.systemStatus.services[serviceName].health = health;
    
    if (status === 'running' && health === 'healthy') {
      this.systemStatus.services[serviceName].uptime = Date.now();
    }
    
    this.checkAndUpdateSystemStatus();
  }
  
  public close(): void {
    this.logger.info('Closing WebSocket server');
    this.io.close();
  }
}