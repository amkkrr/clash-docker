import express from 'express';
import { register, Counter, Histogram, Gauge, collectDefaultMetrics } from 'prom-client';
import { Logger } from './logger';

export class MetricsCollector {
  private logger: Logger;
  private metricsInterval?: NodeJS.Timeout;

  // 指标定义
  private configChangesCounter = new Counter({
    name: 'hot_reload_config_changes_total',
    help: 'Total number of configuration changes detected',
    labelNames: ['severity', 'file_type', 'change_type'],
  });

  private restartDurationHistogram = new Histogram({
    name: 'hot_reload_restart_duration_seconds',
    help: 'Time spent restarting services',
    labelNames: ['service', 'strategy', 'success'],
    buckets: [0.1, 0.5, 1, 5, 10, 30, 60, 120], // 秒
  });

  private connectedClientsGauge = new Gauge({
    name: 'hot_reload_connected_clients',
    help: 'Number of connected WebSocket clients',
  });

  private fileWatcherEventsCounter = new Counter({
    name: 'hot_reload_file_watcher_events_total',
    help: 'Total number of file watcher events',
    labelNames: ['event_type', 'file_path'],
  });

  private serviceHealthGauge = new Gauge({
    name: 'hot_reload_service_health',
    help: 'Health status of monitored services (1=healthy, 0=unhealthy)',
    labelNames: ['service_name'],
  });

  private apiRequestDurationHistogram = new Histogram({
    name: 'hot_reload_api_request_duration_seconds',
    help: 'Duration of API requests',
    labelNames: ['method', 'route', 'status_code'],
    buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 5],
  });

  private apiRequestsCounter = new Counter({
    name: 'hot_reload_api_requests_total',
    help: 'Total number of API requests',
    labelNames: ['method', 'route', 'status_code'],
  });

  private errorCounter = new Counter({
    name: 'hot_reload_errors_total',
    help: 'Total number of errors',
    labelNames: ['error_type', 'component'],
  });

  private memoryUsageGauge = new Gauge({
    name: 'hot_reload_memory_usage_bytes',
    help: 'Memory usage in bytes',
    labelNames: ['type'], // heap_used, heap_total, external, etc.
  });

  private uptimeGauge = new Gauge({
    name: 'hot_reload_uptime_seconds',
    help: 'Service uptime in seconds',
  });

  constructor() {
    this.logger = new Logger('MetricsCollector');

    // 启用默认指标收集 (CPU, 内存等)
    collectDefaultMetrics({
      prefix: 'hot_reload_',
      register,
      gcDurationBuckets: [0.001, 0.01, 0.1, 1, 2, 5],
    });

    // 启动定期指标更新
    this.startPeriodicMetrics();

    this.logger.info('Metrics collector initialized');
  }

  // 配置变更指标
  public recordConfigChange(severity: string, fileType: string, changeType: string): void {
    this.configChangesCounter.labels(severity, fileType, changeType).inc();
    this.logger.debug(`Recorded config change: ${severity}/${fileType}/${changeType}`);
  }

  // 重启耗时指标
  public recordRestartDuration(service: string, strategy: string, success: boolean, durationSeconds: number): void {
    this.restartDurationHistogram.labels(service, strategy, success.toString()).observe(durationSeconds);
    this.logger.debug(`Recorded restart duration: ${service}/${strategy}/${success} = ${durationSeconds}s`);
  }

  // WebSocket客户端数量
  public updateConnectedClients(count: number): void {
    this.connectedClientsGauge.set(count);
  }

  // 文件监控事件
  public recordFileWatcherEvent(eventType: string, filePath: string): void {
    // 只记录文件名，不记录完整路径以保护隐私
    const fileName = filePath.split('/').pop() || 'unknown';
    this.fileWatcherEventsCounter.labels(eventType, fileName).inc();
  }

  // 服务健康状态
  public updateServiceHealth(serviceName: string, isHealthy: boolean): void {
    this.serviceHealthGauge.labels(serviceName).set(isHealthy ? 1 : 0);
  }

  // API请求指标
  public recordApiRequest(method: string, route: string, statusCode: number, durationSeconds: number): void {
    const statusCodeStr = statusCode.toString();

    this.apiRequestsCounter.labels(method, route, statusCodeStr).inc();
    this.apiRequestDurationHistogram.labels(method, route, statusCodeStr).observe(durationSeconds);
  }

  // 错误指标
  public recordError(errorType: string, component: string): void {
    this.errorCounter.labels(errorType, component).inc();
    this.logger.debug(`Recorded error: ${errorType}/${component}`);
  }

  // Express中间件 - API请求监控
  public createApiMetricsMiddleware(): express.RequestHandler {
    return (req: express.Request, res: express.Response, next: express.NextFunction) => {
      const startTime = Date.now();

      // 继续处理请求
      res.on('finish', () => {
        const duration = (Date.now() - startTime) / 1000;
        const route = this.sanitizeRoute(req.route?.path || req.path);

        this.recordApiRequest(req.method, route, res.statusCode, duration);
      });

      next();
    };
  }

  // 获取指标处理器
  public getMetricsHandler(): express.RequestHandler {
    return async (_req: express.Request, res: express.Response) => {
      try {
        res.set('Content-Type', register.contentType);
        res.end(await register.metrics());
      } catch (error) {
        res.status(500).end('Error collecting metrics');
        this.recordError('metrics_collection_failed', 'metrics_collector');
      }
    };
  }

  // 健康检查指标端点
  public getHealthMetricsHandler(): express.RequestHandler {
    return (_req: express.Request, res: express.Response) => {
      const healthMetrics = {
        uptime: process.uptime(),
        memory: process.memoryUsage(),
        connectedClients: this.connectedClientsGauge.get(),
        timestamp: new Date().toISOString(),
      };

      res.json(healthMetrics);
    };
  }

  // 启动定期指标更新
  private startPeriodicMetrics(): void {
    // 只在非测试环境启动定期指标
    if (process.env.NODE_ENV === 'test') {
      return;
    }

    // 每30秒更新一次内存使用情况
    this.metricsInterval = setInterval(() => {
      const memUsage = process.memoryUsage();
      this.memoryUsageGauge.labels('heap_used').set(memUsage.heapUsed);
      this.memoryUsageGauge.labels('heap_total').set(memUsage.heapTotal);
      this.memoryUsageGauge.labels('external').set(memUsage.external);
      this.memoryUsageGauge.labels('array_buffers').set(memUsage.arrayBuffers);

      this.uptimeGauge.set(process.uptime());
    }, 30000);
  }

  // 清理路由路径用于指标
  private sanitizeRoute(route: string): string {
    // 移除动态参数，避免指标基数过高
    return route
      .replace(/\/\d+/g, '/:id') // 数字ID
      .replace(/\/[a-f0-9-]{36}/g, '/:uuid') // UUID
      .replace(/\/[a-zA-Z0-9-_]+$/g, '/:param'); // 末尾参数
  }

  // 重置所有指标 (用于测试)
  public reset(): void {
    register.clear();
    if (this.metricsInterval) {
      clearInterval(this.metricsInterval);
      this.metricsInterval = undefined;
    }
    this.logger.info('All metrics reset');
  }

  // 清理资源
  public cleanup(): void {
    if (this.metricsInterval) {
      clearInterval(this.metricsInterval);
      this.metricsInterval = undefined;
    }
  }

  // 获取当前指标摘要
  public async getMetricsSummary(): Promise<Record<string, unknown>> {
    try {
      return {
        configChanges: await register.getSingleMetric('hot_reload_config_changes_total')?.get(),
        connectedClients: this.connectedClientsGauge.get(),
        uptime: this.uptimeGauge.get(),
        memoryUsage: process.memoryUsage(),
        timestamp: new Date().toISOString(),
      };
    } catch (error) {
      this.logger.error('Error getting metrics summary:', error);
      throw error;
    }
  }
}

// 单例实例
export const metricsCollector = new MetricsCollector();
