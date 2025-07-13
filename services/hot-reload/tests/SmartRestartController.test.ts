import { SmartRestartController } from '../src/services/SmartRestartController';
import { ConfigChange } from '../src/types';

// Mock dockerode
jest.mock('dockerode', () => {
  return jest.fn().mockImplementation(() => ({
    getContainer: jest.fn().mockReturnValue({
      inspect: jest.fn().mockResolvedValue({
        State: { Running: true, Health: { Status: 'healthy' } }
      }),
      stop: jest.fn().mockResolvedValue({}),
      start: jest.fn().mockResolvedValue({}),
      kill: jest.fn().mockResolvedValue({})
    })
  }));
});

describe('SmartRestartController', () => {
  let controller: SmartRestartController;
  
  beforeEach(() => {
    controller = new SmartRestartController('test-project');
  });
  
  afterEach(() => {
    controller.removeAllListeners();
  });
  
  it('should determine restart strategy based on severity', () => {
    const criticalChange: ConfigChange = {
      timestamp: new Date().toISOString(),
      filePath: '.env',
      changeType: 'changed',
      severity: 'critical',
      affectedServices: ['clash']
    };
    
    // 使用私有方法的类型断言
    const strategy = (controller as any).determineRestartStrategy(criticalChange);
    expect(strategy).toBe('full');
  });
  
  it('should calculate restart order correctly', () => {
    const services = ['clash', 'nginx', 'web-ui'];
    const order = (controller as any).calculateRestartOrder(services);
    
    // nginx和web-ui应该在clash之前重启（因为clash依赖它们）
    expect(order.indexOf('web-ui')).toBeLessThan(order.indexOf('nginx'));
    expect(order.indexOf('nginx')).toBeLessThan(order.indexOf('clash'));
  });
  
  it('should provide service dependencies', () => {
    const dependencies = controller.getServiceDependencies();
    expect(dependencies).toHaveProperty('clash');
    expect(dependencies.clash).toContain('nginx');
  });
  
  it('should handle config changes', async () => {
    const change: ConfigChange = {
      timestamp: new Date().toISOString(),
      filePath: '.env',
      changeType: 'changed',
      severity: 'minor',
      affectedServices: ['clash']
    };
    
    const eventSpy = jest.fn();
    controller.on('restartStarted', eventSpy);
    
    await expect(controller.handleConfigChange(change)).resolves.not.toThrow();
    expect(eventSpy).toHaveBeenCalledWith({ change });
  });
});