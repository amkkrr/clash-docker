# Hot Reload Service

A Node.js-based configuration hot reload service for Clash Docker.

## Features

- 🔍 **Real-time file monitoring** using Chokidar
- ⚡ **Smart restart strategies** based on change severity
- 🌐 **WebSocket real-time updates** for frontend integration
- 🐳 **Docker integration** with intelligent container management
- 📊 **Comprehensive logging** and monitoring
- 🛡️ **Type safety** with TypeScript

## Quick Start

### Development

```bash
# Install dependencies
npm install

# Run in development mode
npm run dev

# Run tests
npm test

# Build for production
npm run build
```

### Production with Docker

```bash
# Start the service
./scripts/start-hot-reload.sh

# View logs
docker-compose -f docker-compose.hot-reload.yml logs -f hot-reload

# Stop the service
docker-compose -f docker-compose.hot-reload.yml down
```

## API Endpoints

- `GET /health` - Health check
- `GET /api/status` - Current system status
- `GET /api/watched-paths` - Monitored file paths
- `GET /api/clients` - Connected WebSocket clients count
- `POST /api/restart/:service` - Manual service restart
- `GET /api/dependencies` - Service dependency graph

## WebSocket Events

Connect to `ws://localhost:8080/ws/config-status` to receive:

- `config_change` - Configuration file changes
- `restart_progress` - Service restart progress
- `restart_completed` - Restart completion status
- `status_update` - System status updates
- `error` - Error notifications

## Configuration

Environment variables (see `.env.example`):

- `PORT` - HTTP server port (default: 8080)
- `CONFIG_BASE_PATH` - Base path for config files
- `WATCH_PATHS` - Comma-separated paths to monitor
- `DEBOUNCE_TIME` - File change debounce time (ms)
- `RESTART_STRATEGY` - Default restart strategy
- `LOG_LEVEL` - Logging level

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ ConfigFileWatcher│───▶│SmartRestartCtrl │───▶│  Docker API     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       
         ▼                       ▼                       
┌─────────────────┐    ┌─────────────────┐              
│RealtimeBroadcast│◀───│  Express API    │              
└─────────────────┘    └─────────────────┘              
         │                                               
         ▼                                               
┌─────────────────┐                                     
│   WebSocket     │                                     
│   Clients       │                                     
└─────────────────┘                                     
```

## Service Dependencies

The restart controller manages service dependencies:

- `clash` depends on `nginx`, `web-ui`
- `nginx` depends on `web-ui`
- `web-ui` has no dependencies
- `config-watcher` has no dependencies

## Restart Strategies

1. **Critical** changes → Full system restart
2. **Moderate** changes → Selective service restart
3. **Minor** changes → Configuration reload only

## Testing

```bash
# Run all tests
npm test

# Run with coverage
npm test -- --coverage

# Run specific test
npm test ConfigFileWatcher.test.ts

# Integration tests
./scripts/test-hot-reload.sh
```

## Monitoring

The service provides comprehensive monitoring:

- File change detection and analysis
- Service restart metrics
- WebSocket connection tracking
- System health monitoring
- Error reporting and alerting

## Security

- Non-privileged container user
- Read-only configuration file mounts
- Controlled Docker socket access
- Input validation and sanitization
- Comprehensive error handling

## Contributing

1. Follow TypeScript best practices
2. Add tests for new features
3. Update documentation
4. Follow semantic versioning

## License

MIT License