# Clash Docker Hot Reload - Makefile
# 提供便捷的开发、测试、构建和部署命令

.PHONY: help install dev test build deploy clean lint format security audit docs ci-local

# 默认目标 - 显示帮助信息
help:
	@echo "🔄 Clash Docker Hot Reload - Available Commands:"
	@echo ""
	@echo "📦 Development:"
	@echo "  install           Install dependencies for hot reload service"
	@echo "  dev               Start development server with hot reload"
	@echo "  dev-logs          Follow development logs"
	@echo ""
	@echo "🧪 Testing:"
	@echo "  test              Run all tests"
	@echo "  test-unit         Run unit tests only"
	@echo "  test-integration  Run integration tests"
	@echo "  test-coverage     Run tests with coverage report"
	@echo "  test-watch        Run tests in watch mode"
	@echo ""
	@echo "🏗️ Build & Deploy:"
	@echo "  build             Build production Docker image"
	@echo "  build-dev         Build development Docker image"
	@echo "  deploy-dev        Deploy to development environment"
	@echo "  deploy-prod       Deploy to production environment"
	@echo "  deploy-local      Deploy locally for testing"
	@echo ""
	@echo "🔍 Code Quality:"
	@echo "  lint              Run ESLint checker"
	@echo "  lint-fix          Fix ESLint issues automatically"
	@echo "  format            Format code with Prettier"
	@echo "  format-check      Check code formatting"
	@echo "  typecheck         Run TypeScript type checking"
	@echo ""
	@echo "🛡️ Security & Audit:"
	@echo "  security          Run security vulnerability scan"
	@echo "  audit             Run npm audit"
	@echo "  docker-scan       Scan Docker images for vulnerabilities"
	@echo ""
	@echo "📚 Documentation:"
	@echo "  docs              Generate documentation"
	@echo "  docs-serve        Serve documentation locally"
	@echo ""
	@echo "⚙️ CI/CD & Utilities:"
	@echo "  ci-local          Run full CI pipeline locally"
	@echo "  pre-commit        Install pre-commit hooks"
	@echo "  clean             Clean up build artifacts and containers"
	@echo "  status            Show service status"
	@echo "  logs              Show service logs"

# 📦 开发环境设置
install:
	@echo "📦 Installing hot reload service dependencies..."
	cd services/hot-reload && npm ci
	@echo "✅ Dependencies installed"

dev:
	@echo "🚀 Starting hot reload development server..."
	cd services/hot-reload && npm run dev

dev-logs:
	@echo "📋 Following development logs..."
	docker-compose -f docker-compose.hot-reload.yml logs -f hot-reload

# 🧪 测试命令
test:
	@echo "🧪 Running all tests..."
	cd services/hot-reload && npm test
	./scripts/test-hot-reload.sh

test-unit:
	@echo "🧪 Running unit tests..."
	cd services/hot-reload && npm test -- --testPathPattern=".*\.test\.ts$$"

test-integration:
	@echo "🧪 Running integration tests..."
	./scripts/test-hot-reload.sh

test-coverage:
	@echo "🧪 Running tests with coverage..."
	cd services/hot-reload && npm run test:coverage

test-watch:
	@echo "🧪 Running tests in watch mode..."
	cd services/hot-reload && npm run test:watch

# 🏗️ 构建和部署
build:
	@echo "🏗️ Building production Docker image..."
	docker build -t clash-hot-reload:latest services/hot-reload/
	@echo "✅ Production image built: clash-hot-reload:latest"

build-dev:
	@echo "🏗️ Building development Docker image..."
	docker build -t clash-hot-reload:dev services/hot-reload/ --target builder
	@echo "✅ Development image built: clash-hot-reload:dev"

deploy-dev:
	@echo "🚀 Deploying to development environment..."
	docker-compose -f docker-compose.hot-reload.yml up -d
	@echo "⏳ Waiting for services to be ready..."
	timeout 60 bash -c 'until curl -f http://localhost:8080/health >/dev/null 2>&1; do sleep 3; done'
	@echo "✅ Development deployment complete"
	@echo "📡 Service available at: http://localhost:8080"

deploy-prod:
	@echo "🚀 Deploying to production environment..."
	@echo "⚠️  This will start the full production stack with monitoring"
	@read -p "Continue? [y/N] " confirm && [ "$$confirm" = "y" ]
	docker-compose -f docker-compose.hot-reload.yml -f docker-compose.prod.yml up -d
	@echo "⏳ Waiting for services to be ready..."
	timeout 180 bash -c 'until curl -f http://localhost:8080/health >/dev/null 2>&1; do sleep 5; done'
	timeout 120 bash -c 'until curl -f http://localhost:9091 >/dev/null 2>&1; do sleep 3; done'
	timeout 120 bash -c 'until curl -f http://localhost:3000 >/dev/null 2>&1; do sleep 3; done'
	@echo "✅ Production deployment complete"
	@echo "📊 Monitoring Stack:"
	@echo "   🔧 Hot Reload API: http://localhost:8080"
	@echo "   📈 Prometheus: http://localhost:9091"
	@echo "   📊 Grafana: http://localhost:3000 (admin/admin123)"
	@echo "   📋 Logs: http://localhost:3100"

deploy-local:
	@echo "🚀 Deploying locally for testing..."
	./scripts/start-hot-reload.sh

# 🔍 代码质量检查
lint:
	@echo "🔍 Running ESLint..."
	cd services/hot-reload && npm run lint

lint-fix:
	@echo "🔧 Fixing ESLint issues..."
	cd services/hot-reload && npm run lint:fix

format:
	@echo "💅 Formatting code with Prettier..."
	cd services/hot-reload && npm run format

format-check:
	@echo "💅 Checking code formatting..."
	cd services/hot-reload && npm run format:check

typecheck:
	@echo "🔍 Running TypeScript type checking..."
	cd services/hot-reload && npm run typecheck

# 🛡️ 安全和审计
security:
	@echo "🛡️ Running security scans..."
	cd services/hot-reload && npm audit --audit-level moderate
	$(MAKE) docker-scan

audit:
	@echo "🔍 Running npm audit..."
	cd services/hot-reload && npm audit

docker-scan:
	@echo "🐳 Scanning Docker image for vulnerabilities..."
	if command -v trivy >/dev/null 2>&1; then \
		trivy image clash-hot-reload:latest; \
	else \
		echo "⚠️ Trivy not installed. Install with: curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin"; \
	fi

# 📚 文档
docs:
	@echo "📚 Generating documentation..."
	cd services/hot-reload && npx typedoc src --out docs --theme default

docs-serve:
	@echo "📚 Serving documentation locally..."
	cd services/hot-reload && python3 -m http.server 8000 --directory docs

# ⚙️ CI/CD和工具
ci-local:
	@echo "🔄 Running full CI pipeline locally..."
	if command -v act >/dev/null 2>&1; then \
		act -W .github/workflows/hot-reload-ci.yml; \
	else \
		echo "⚠️ 'act' not installed. Running manual CI steps..."; \
		$(MAKE) install lint typecheck test build; \
	fi

pre-commit:
	@echo "🔧 Installing pre-commit hooks..."
	if command -v pre-commit >/dev/null 2>&1; then \
		pre-commit install; \
		echo "✅ Pre-commit hooks installed"; \
	else \
		echo "⚠️ pre-commit not installed. Install with: pip install pre-commit"; \
	fi

# 🧹 清理命令
clean:
	@echo "🧹 Cleaning up..."
	cd services/hot-reload && npm run clean
	docker-compose -f docker-compose.hot-reload.yml down -v --remove-orphans || true
	docker system prune -f --volumes
	@echo "✅ Cleanup complete"

clean-images:
	@echo "🧹 Cleaning Docker images..."
	docker rmi clash-hot-reload:latest clash-hot-reload:dev clash-hot-reload:test || true
	docker image prune -f
	@echo "✅ Docker images cleaned"

# 📊 状态和监控
status:
	@echo "📊 Hot Reload Service Status:"
	@echo "================================"
	@if curl -f http://localhost:8080/health >/dev/null 2>&1; then \
		echo "✅ Service: RUNNING"; \
		echo "📡 Health: $$(curl -s http://localhost:8080/health | jq -r '.status // "unknown"')"; \
		echo "🔗 API: http://localhost:8080"; \
		echo "🌐 WebSocket: ws://localhost:8080/ws/config-status"; \
		echo "👥 Connected Clients: $$(curl -s http://localhost:8080/api/clients | jq -r '.connectedClients // 0')"; \
		echo "📁 Watched Paths: $$(curl -s http://localhost:8080/api/watched-paths | jq -r '.paths | length // 0') paths"; \
	else \
		echo "❌ Service: NOT RUNNING"; \
		echo "💡 Start with: make deploy-dev"; \
	fi
	@echo ""
	@echo "📊 Monitoring Stack Status:"
	@if curl -f http://localhost:9091 >/dev/null 2>&1; then \
		echo "✅ Prometheus: RUNNING (http://localhost:9091)"; \
	else \
		echo "❌ Prometheus: NOT RUNNING"; \
	fi
	@if curl -f http://localhost:3000 >/dev/null 2>&1; then \
		echo "✅ Grafana: RUNNING (http://localhost:3000)"; \
	else \
		echo "❌ Grafana: NOT RUNNING"; \
	fi
	@if curl -f http://localhost:3100/ready >/dev/null 2>&1; then \
		echo "✅ Loki: RUNNING (http://localhost:3100)"; \
	else \
		echo "❌ Loki: NOT RUNNING"; \
	fi
	@echo ""
	@echo "🐳 Docker Status:"
	@docker-compose -f docker-compose.hot-reload.yml ps 2>/dev/null || echo "No containers running"

logs:
	@echo "📋 Hot Reload Service Logs:"
	@echo "=========================="
	docker-compose -f docker-compose.hot-reload.yml logs --tail 50 hot-reload

logs-follow:
	@echo "📋 Following Hot Reload Service Logs..."
	docker-compose -f docker-compose.hot-reload.yml logs -f hot-reload

# 🔧 开发工具
restart:
	@echo "🔄 Restarting hot reload service..."
	docker-compose -f docker-compose.hot-reload.yml restart hot-reload
	@echo "✅ Service restarted"

shell:
	@echo "🐚 Opening shell in hot reload container..."
	docker-compose -f docker-compose.hot-reload.yml exec hot-reload sh

# 📈 性能测试
perf-test:
	@echo "📈 Running performance tests..."
	@echo "Testing startup time..."
	@start_time=$$(date +%s); \
	$(MAKE) deploy-dev >/dev/null 2>&1; \
	end_time=$$(date +%s); \
	startup_time=$$((end_time - start_time)); \
	echo "⏱️ Startup time: $${startup_time}s"; \
	if [ $$startup_time -gt 30 ]; then \
		echo "⚠️ Startup time is slow (>30s)"; \
	else \
		echo "✅ Startup time is acceptable"; \
	fi

# 🚀 快速启动命令
quick-start: install build deploy-dev status
	@echo ""
	@echo "🎉 Hot Reload Service is ready!"
	@echo "📖 API Documentation: http://localhost:8080"
	@echo "🔧 Management: make status | make logs | make restart"

# 🚦 健康检查
health:
	@if curl -f http://localhost:8080/health >/dev/null 2>&1; then \
		echo "✅ Service is healthy"; \
		curl -s http://localhost:8080/health | jq; \
	else \
		echo "❌ Service is not responding"; \
		exit 1; \
	fi

# 📋 完整的开发工作流
dev-workflow: clean install lint typecheck test build deploy-dev status
	@echo ""
	@echo "🎯 Development workflow completed successfully!"
	@echo "🔗 Service: http://localhost:8080"