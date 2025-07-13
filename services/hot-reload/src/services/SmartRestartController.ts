import Docker from 'dockerode';
import { EventEmitter } from 'events';
import { ConfigChange, RestartResult, ServiceDependency } from '../types';
import { Logger } from '../utils/logger';
import { metricsCollector } from '../utils/metrics';

export class SmartRestartController extends EventEmitter {
  private docker: Docker;
  private serviceDependencies: ServiceDependency;
  private projectName: string;
  private logger: Logger;

  constructor(projectName: string = 'clash-docker') {
    super();
    this.docker = new Docker();
    this.projectName = projectName;
    this.logger = new Logger('SmartRestartController');
    this.serviceDependencies = {
      clash: ['nginx', 'web-ui'],
      nginx: ['web-ui'],
      'web-ui': [],
      'config-watcher': [],
    };
  }

  public async handleConfigChange(change: ConfigChange): Promise<void> {
    this.logger.info(`Handling config change: ${change.filePath} (${change.severity})`);
    this.emit('restartStarted', { change });

    try {
      const strategy = this.determineRestartStrategy(change);
      this.logger.info(`Using restart strategy: ${strategy}`);

      const result = await this.executeRestartStrategy(strategy, change);

      this.emit('restartCompleted', { change, result });
      this.logger.info(`Restart completed successfully for ${change.affectedServices.join(', ')}`);
    } catch (error) {
      this.logger.error(`Restart failed for ${change.filePath}:`, error);
      this.emit('restartFailed', { change, error: error instanceof Error ? error.message : 'Unknown error' });
      throw error;
    }
  }

  private determineRestartStrategy(change: ConfigChange): 'full' | 'selective' | 'reload' {
    switch (change.severity) {
      case 'critical':
        return 'full';
      case 'moderate':
        return 'selective';
      case 'minor':
        return 'reload';
      default:
        return 'reload';
    }
  }

  private async executeRestartStrategy(strategy: string, change: ConfigChange): Promise<RestartResult[]> {
    switch (strategy) {
      case 'full':
        return this.fullRestart();
      case 'selective':
        return this.selectiveRestart(change.affectedServices);
      case 'reload':
        return this.reloadConfigOnly(change.affectedServices);
      default:
        throw new Error(`Unknown restart strategy: ${strategy}`);
    }
  }

  private async selectiveRestart(services: string[]): Promise<RestartResult[]> {
    const restartOrder = this.calculateRestartOrder(services);
    const results: RestartResult[] = [];

    this.logger.info(`Restarting services in order: ${restartOrder.join(' -> ')}`);

    for (const service of restartOrder) {
      const startTime = Date.now();

      try {
        this.emit('serviceRestarting', { service, status: 'starting' });

        // 1. 预检查
        await this.preRestartHealthCheck(service);

        // 2. 优雅重启
        await this.restartServiceGracefully(service);

        // 3. 健康检查
        await this.waitForServiceHealth(service);

        const duration = (Date.now() - startTime) / 1000;
        const result: RestartResult = {
          success: true,
          service,
          duration: duration * 1000,
        };

        // 记录重启指标
        metricsCollector.recordRestartDuration(service, 'selective', true, duration);
        metricsCollector.updateServiceHealth(service, true);

        results.push(result);
        this.emit('serviceRestarted', { service, status: 'healthy', duration });
        this.logger.info(`Service ${service} restarted successfully in ${duration}s`);
      } catch (error) {
        const duration = (Date.now() - startTime) / 1000;
        const result: RestartResult = {
          success: false,
          service,
          duration: duration * 1000,
          error: error instanceof Error ? error.message : 'Unknown error',
        };

        // 记录失败指标
        metricsCollector.recordRestartDuration(service, 'selective', false, duration);
        metricsCollector.updateServiceHealth(service, false);
        metricsCollector.recordError('service_restart_failed', 'smart_restart_controller');

        results.push(result);
        this.emit('serviceRestartFailed', { service, error: error instanceof Error ? error.message : 'Unknown error' });
        this.logger.error(`Service ${service} restart failed:`, error);

        // 处理重启失败
        await this.handleRestartFailure(service, error);
      }
    }

    return results;
  }

  private async restartServiceGracefully(serviceName: string): Promise<void> {
    const containerName = `${this.projectName}-${serviceName}-1`;

    try {
      const container = this.docker.getContainer(containerName);

      // 检查容器是否存在
      const containerInfo = await container.inspect();

      if (containerInfo.State.Running) {
        this.logger.info(`Stopping service ${serviceName}...`);
        // 优雅停止 (给容器10秒时间优雅关闭)
        await container.stop({ t: 10 });

        // 等待完全停止
        await this.waitForContainerStop(container);
      }

      this.logger.info(`Starting service ${serviceName}...`);
      // 启动容器
      await container.start();

      // 等待容器就绪
      await this.waitForContainerReady(container);
    } catch (error) {
      throw new Error(
        `Failed to restart service ${serviceName}: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }

  private async waitForContainerStop(container: Docker.Container, timeout: number = 30000): Promise<void> {
    const startTime = Date.now();

    while (Date.now() - startTime < timeout) {
      try {
        const info = await container.inspect();
        if (!info.State.Running) {
          return;
        }
      } catch (error) {
        // 容器可能已经被删除，这也算停止
        return;
      }

      await this.sleep(1000); // 等待1秒
    }

    throw new Error('Container stop timeout');
  }

  private async waitForContainerReady(container: Docker.Container, timeout: number = 60000): Promise<void> {
    const startTime = Date.now();

    while (Date.now() - startTime < timeout) {
      try {
        const info = await container.inspect();
        if (info.State.Running && info.State.Health?.Status === 'healthy') {
          return;
        }
        if (info.State.Running && !info.State.Health) {
          // 没有健康检查的容器，只要运行就认为就绪
          await this.sleep(2000); // 给容器2秒启动时间
          return;
        }
      } catch (error) {
        // 继续等待
      }

      await this.sleep(2000); // 等待2秒
    }

    throw new Error('Container ready timeout');
  }

  private calculateRestartOrder(services: string[]): string[] {
    // 根据依赖关系计算重启顺序
    const order: string[] = [];
    const visited = new Set<string>();

    const visit = (service: string) => {
      if (visited.has(service)) return;
      visited.add(service);

      // 先处理依赖的服务
      const dependencies = this.serviceDependencies[service] || [];
      for (const dep of dependencies) {
        if (services.includes(dep)) {
          visit(dep);
        }
      }

      order.push(service);
    };

    for (const service of services) {
      visit(service);
    }

    return order;
  }

  private async preRestartHealthCheck(serviceName: string): Promise<void> {
    // 重启前健康检查，确保服务当前状态正常
    const containerName = `${this.projectName}-${serviceName}-1`;

    try {
      const container = this.docker.getContainer(containerName);
      const info = await container.inspect();

      if (!info.State.Running) {
        this.logger.warn(`Service ${serviceName} is not running, will attempt to start`);
      }
    } catch (error) {
      throw new Error(
        `Pre-restart health check failed for ${serviceName}: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }

  private async waitForServiceHealth(serviceName: string, timeout: number = 30000): Promise<void> {
    // 等待服务恢复健康状态
    const containerName = `${this.projectName}-${serviceName}-1`;
    const container = this.docker.getContainer(containerName);

    await this.waitForContainerReady(container, timeout);
  }

  private async handleRestartFailure(serviceName: string, error: any): Promise<void> {
    // 重启失败处理逻辑
    this.logger.error(`Service ${serviceName} restart failed:`, error);

    // 可以实现自动回滚逻辑
    // await this.rollbackService(serviceName);
  }

  private async fullRestart(): Promise<RestartResult[]> {
    // 全量重启所有服务
    const allServices = Object.keys(this.serviceDependencies);
    this.logger.info('Performing full system restart');
    return this.selectiveRestart(allServices);
  }

  private async reloadConfigOnly(services: string[]): Promise<RestartResult[]> {
    // 仅重载配置，不重启服务
    const results: RestartResult[] = [];

    this.logger.info(`Reloading configuration for services: ${services.join(', ')}`);

    for (const service of services) {
      const startTime = Date.now();

      try {
        // 发送配置重载信号
        await this.sendConfigReloadSignal(service);

        const duration = Date.now() - startTime;
        results.push({
          success: true,
          service,
          duration,
        });
        this.logger.info(`Configuration reloaded for ${service} in ${duration}ms`);
      } catch (error) {
        const duration = Date.now() - startTime;
        results.push({
          success: false,
          service,
          duration,
          error: error instanceof Error ? error.message : 'Unknown error',
        });
        this.logger.error(`Failed to reload configuration for ${service}:`, error);
      }
    }

    return results;
  }

  private async sendConfigReloadSignal(serviceName: string): Promise<void> {
    // 发送配置重载信号到服务
    const containerName = `${this.projectName}-${serviceName}-1`;

    try {
      const container = this.docker.getContainer(containerName);

      // 发送 SIGHUP 信号重载配置
      await container.kill({ signal: 'SIGHUP' });
      this.logger.info(`Sent SIGHUP signal to ${serviceName}`);
    } catch (error) {
      throw new Error(
        `Failed to send reload signal to ${serviceName}: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  public getServiceDependencies(): ServiceDependency {
    return { ...this.serviceDependencies };
  }

  public updateServiceDependencies(dependencies: ServiceDependency): void {
    this.serviceDependencies = { ...dependencies };
    this.logger.info('Service dependencies updated');
  }
}
