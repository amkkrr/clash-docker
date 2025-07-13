import { RealtimeBroadcaster } from '../src/services/RealtimeBroadcaster';
import { createServer } from 'http';
import { ConfigChange, RestartResult } from '../src/types';
import { Server as SocketIOServer } from 'socket.io';
import Client from 'socket.io-client';

describe('RealtimeBroadcaster', () => {
  let httpServer: any;
  let broadcaster: RealtimeBroadcaster;
  let clientSocket: any;
  let serverSocket: any;
  
  beforeEach((done) => {
    httpServer = createServer();
    broadcaster = new RealtimeBroadcaster(httpServer);
    
    httpServer.listen(() => {
      const port = httpServer.address().port;
      clientSocket = Client(`http://localhost:${port}`, {
        path: '/ws/config-status'
      });
      
      broadcaster['io'].on('connection', (socket) => {
        serverSocket = socket;
      });
      
      clientSocket.on('connect', done);
    });
  });
  
  afterEach(() => {
    broadcaster.close();
    clientSocket.close();
    httpServer.close();
  });
  
  it('should broadcast config changes', (done) => {
    const change: ConfigChange = {
      timestamp: new Date().toISOString(),
      filePath: '.env',
      changeType: 'changed',
      severity: 'moderate',
      affectedServices: ['clash']
    };
    
    clientSocket.on('message', (message: any) => {
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
    const results: RestartResult[] = [
      { success: true, service: 'clash', duration: 5000 }
    ];
    
    clientSocket.on('message', (message: any) => {
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