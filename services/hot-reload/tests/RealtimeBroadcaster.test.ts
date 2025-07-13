import { RealtimeBroadcaster } from '../src/services/RealtimeBroadcaster';
import { createServer, Server } from 'http';
import { AddressInfo } from 'net';
import { ConfigChange, RestartResult } from '../src/types';
import Client, { Socket } from 'socket.io-client';

// 模拟环境变量以避免metrics interval
process.env.NODE_ENV = 'test';

describe('RealtimeBroadcaster', () => {
  let httpServer: Server;
  let broadcaster: RealtimeBroadcaster;
  let clientSocket: Socket;

  beforeEach((done) => {
    httpServer = createServer();
    broadcaster = new RealtimeBroadcaster(httpServer);

    httpServer.listen(() => {
      const address = httpServer.address();
      const port = address && typeof address !== 'string' ? (address as AddressInfo).port : 3000;
      clientSocket = Client(`http://localhost:${port}`, {
        path: '/ws/config-status',
      });

      clientSocket.on('connect', done);
    });
  });

  afterEach(() => {
    broadcaster.close();
    (clientSocket as Socket).close();
    httpServer.close();
  });

  it('should broadcast config changes', (done) => {
    const change: ConfigChange = {
      timestamp: new Date().toISOString(),
      filePath: '.env',
      changeType: 'changed',
      severity: 'moderate',
      affectedServices: ['clash'],
    };

    (clientSocket as Socket).on('message', (message: { type: string; data: Record<string, unknown> }) => {
      if (message.type === 'config_change') {
        expect(message.data.filePath).toBe('.env');
        expect(message.data.severity).toBe('moderate');
        done();
      }
    });

    broadcaster.broadcastConfigChange(change);
  });

  it('should track connected clients', () => {
    expect(broadcaster.getConnectedClientsCount()).toBe(1);
  });

  it('should provide current system status', () => {
    const status = broadcaster.getCurrentSystemStatus();
    expect(status).toHaveProperty('status');
    expect(status).toHaveProperty('services');
    expect(status).toHaveProperty('lastUpdate');
  });

  it('should broadcast restart completion', (done) => {
    const results: RestartResult[] = [{ success: true, service: 'clash', duration: 5000 }];

    (clientSocket as Socket).on('message', (message: { type: string; data: Record<string, unknown> }) => {
      if (message.type === 'restart_completed') {
        expect(message.data.results).toEqual(results);
        expect(message.data.successCount).toBe(1);
        done();
      }
    });

    broadcaster.broadcastRestartCompleted(results);
  });

  it('should update service status', () => {
    broadcaster.updateServiceStatus('clash', 'running', 'healthy');

    const status = broadcaster.getCurrentSystemStatus();
    expect(status.services.clash.status).toBe('running');
    expect(status.services.clash.health).toBe('healthy');
  });
});
