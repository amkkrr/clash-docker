import express from 'express';
import cors from 'cors';
import { createServer, Server } from 'http';
import dotenv from 'dotenv';
import path from 'path';
import { ConfigFileWatcher } from './services/ConfigFileWatcher';
import { SmartRestartController } from './services/SmartRestartController';
import { RealtimeBroadcaster } from './services/RealtimeBroadcaster';
import { Logger } from './utils/logger';
import { metricsCollector } from './utils/metrics';

// 加载环境变量
dotenv.config();

class HotReloadApp {
  private app: express.Application;
  private server: Server | null = null;
  private logger: Logger;
  private configWatcher?: ConfigFileWatcher;
  private restartController?: SmartRestartController;
  private broadcaster?: RealtimeBroadcaster;

  constructor() {
    this.app = express();
    this.logger = new Logger('HotReloadApp');
    this.setupMiddleware();
    this.setupRoutes();
  }

  private setupMiddleware(): void {
    // CORS配置
    this.app.use(
      cors({
        origin: process.env.CORS_ORIGIN || '*',
        methods: ['GET', 'POST'],
        credentials: true,
      })
    );

    // JSON解析
    this.app.use(express.json());
    this.app.use(express.urlencoded({ extended: true }));

    // 指标收集中间件
    this.app.use(metricsCollector.createApiMetricsMiddleware());

    // 日志中间件
    this.app.use((req, _res, next) => {
      this.logger.info(`${req.method} ${req.path} - ${req.ip}`);
      next();
    });
  }

  private setupRoutes(): void {
    // 健康检查端点
    this.app.get('/health', (_req, res) => {
      res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        version: process.env.npm_package_version || '1.0.0',
      });
    });

    // 获取系统状态
    this.app.get('/api/status', (_req, res) => {
      if (this.broadcaster) {
        const status = this.broadcaster.getCurrentSystemStatus();
        res.json(status);
      } else {
        res.status(503).json({ error: 'Service not ready' });
      }
    });

    // 获取监控的文件路径
    this.app.get('/api/watched-paths', (_req, res) => {
      if (this.configWatcher) {
        const paths = this.configWatcher.getWatchedPaths();
        res.json({ paths });
      } else {
        res.status(503).json({ error: 'Service not ready' });
      }
    });

    // 获取连接的客户端数量
    this.app.get('/api/clients', (_req, res) => {
      if (this.broadcaster) {
        const count = this.broadcaster.getConnectedClientsCount();
        res.json({ connectedClients: count });
      } else {
        res.status(503).json({ error: 'Service not ready' });
      }
    });

    // 手动触发服务重启
    this.app.post('/api/restart/:service', async (req, res) => {
      try {
        const { service } = req.params;
        const { force = false } = req.body;

        if (!this.restartController) {
          res.status(503).json({ error: 'Service not ready' });
          return;
        }

        // 创建一个手动配置变更事件
        const manualChange = {
          timestamp: new Date().toISOString(),
          filePath: 'manual-trigger',
          changeType: 'changed' as const,
          severity: force ? ('critical' as const) : ('moderate' as const),
          affectedServices: [service],
        };

        const results = await this.restartController.handleConfigChange(manualChange);
        res.json({ success: true, results });
      } catch (error) {
        this.logger.error('Manual restart failed:', error);
        res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
      }
    });

    // 获取服务依赖关系
    this.app.get('/api/dependencies', (_req, res) => {
      if (this.restartController) {
        const dependencies = this.restartController.getServiceDependencies();
        res.json({ dependencies });
      } else {
        res.status(503).json({ error: 'Service not ready' });
      }
    });

    // Prometheus 指标端点
    this.app.get('/metrics', metricsCollector.getMetricsHandler());

    // 健康指标端点
    this.app.get('/api/metrics/health', metricsCollector.getHealthMetricsHandler());

    // 404处理
    this.app.use('*', (_req, res) => {
      res.status(404).json({ error: 'Not found' });
    });

    // 错误处理中间件
    this.app.use((err: Error, _req: express.Request, res: express.Response) => {
      this.logger.error('Express error:', err);
      res.status(500).json({ error: 'Internal server error' });
    });
  }

  public async start(): Promise<void> {
    try {
      // 创建HTTP服务器
      this.server = createServer(this.app);

      // 初始化WebSocket广播器
      this.broadcaster = new RealtimeBroadcaster(this.server);

      // 初始化重启控制器
      this.restartController = new SmartRestartController(process.env.COMPOSE_PROJECT_NAME || 'clash-docker');

      // 设置重启控制器事件监听
      this.setupRestartControllerEvents();

      // 初始化文件监控器
      const watchPaths = this.getWatchPaths();
      this.configWatcher = new ConfigFileWatcher(watchPaths);

      // 设置文件监控器事件监听
      this.setupConfigWatcherEvents();

      // 启动HTTP服务器
      const port = parseInt(process.env.PORT || '8080');
      this.server.listen(port, () => {
        this.logger.info(`Hot reload service started on port ${port}`);
        this.logger.info(`WebSocket endpoint: ws://localhost:${port}/ws/config-status`);
        this.logger.info(`Watching paths: ${watchPaths.join(', ')}`);
      });
    } catch (error) {
      this.logger.error('Failed to start hot reload service:', error);
      throw error;
    }
  }

  private getWatchPaths(): string[] {
    const basePath = process.env.CONFIG_BASE_PATH || '/app/config';
    const watchPaths = process.env.WATCH_PATHS || '.env,config.yaml,rules/,templates/';

    return watchPaths.split(',').map((p) => path.resolve(basePath, p.trim()));
  }

  private setupConfigWatcherEvents(): void {
    if (!this.configWatcher || !this.broadcaster || !this.restartController) {
      throw new Error('Services not initialized');
    }

    // 监听配置变化事件
    this.configWatcher.on('configChange', async (change) => {
      try {
        this.logger.info(`Config change detected: ${change.filePath} (${change.severity})`);

        // 广播配置变化
        this.broadcaster!.broadcastConfigChange(change);

        // 处理重启
        await this.restartController!.handleConfigChange(change);
      } catch (error) {
        this.logger.error('Error handling config change:', error);
        this.broadcaster!.broadcastError('Config change handling failed', {
          message: error instanceof Error ? error.message : 'Unknown error',
        });
      }
    });

    // 监听错误事件
    this.configWatcher.on('error', (error) => {
      this.logger.error('Config watcher error:', error);
      this.broadcaster!.broadcastError('Config watcher error', {
        message: error instanceof Error ? error.message : 'Unknown error',
      });
    });
  }

  private setupRestartControllerEvents(): void {
    if (!this.restartController || !this.broadcaster) {
      throw new Error('Services not initialized');
    }

    // 监听重启开始事件
    this.restartController.on('restartStarted', ({ change }) => {
      this.logger.info(`Restart started for: ${change.affectedServices.join(', ')}`);
      this.broadcaster!.updateSystemStatus('restarting');
    });

    // 监听服务重启事件
    this.restartController.on('serviceRestarting', ({ service, status }) => {
      this.broadcaster!.broadcastRestartProgress(service, status);
    });

    // 监听服务重启完成事件
    this.restartController.on('serviceRestarted', ({ service, status }) => {
      this.broadcaster!.broadcastRestartProgress(service, status);
    });

    // 监听服务重启失败事件
    this.restartController.on('serviceRestartFailed', ({ service, error }) => {
      this.broadcaster!.broadcastRestartProgress(service, 'failed');
      this.broadcaster!.broadcastError(`Service ${service} restart failed`, error);
    });

    // 监听重启完成事件
    this.restartController.on('restartCompleted', ({ result }) => {
      this.broadcaster!.broadcastRestartCompleted(result);
    });

    // 监听重启失败事件
    this.restartController.on('restartFailed', ({ change, error }) => {
      this.broadcaster!.broadcastError('Restart failed', { change, error });
    });
  }

  public async stop(): Promise<void> {
    this.logger.info('Stopping hot reload service...');

    try {
      // 停止文件监控
      if (this.configWatcher) {
        this.configWatcher.stop();
      }

      // 关闭WebSocket连接
      if (this.broadcaster) {
        this.broadcaster.close();
      }

      // 关闭HTTP服务器
      if (this.server) {
        await new Promise<void>((resolve) => {
          this.server!.close(() => {
            this.logger.info('HTTP server closed');
            resolve();
          });
        });
      }

      this.logger.info('Hot reload service stopped');
    } catch (error) {
      this.logger.error('Error stopping service:', error);
      throw error;
    }
  }
}

// 创建应用实例
const app = new HotReloadApp();

// 处理进程信号
process.on('SIGTERM', async () => {
  console.log('Received SIGTERM, shutting down gracefully...');
  await app.stop();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('Received SIGINT, shutting down gracefully...');
  await app.stop();
  process.exit(0);
});

// 处理未捕获的异常
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

// 启动应用
if (require.main === module) {
  app.start().catch((error) => {
    console.error('Failed to start application:', error);
    process.exit(1);
  });
}

export default app;
