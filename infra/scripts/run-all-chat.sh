# #!/bin/bash
# set -e

# echo "=== Phase 2: Containerize and Run All Services ==="

# # Colors for output
# RED='\033[0;31m'
# GREEN='\033[0;32m'
# YELLOW='\033[1;33m'
# NC='\033[0m' # No Color

# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# NETWORK_NAME="eventhub-net"

# # Function to print status
# print_status() {
#     echo -e "${GREEN}[*]${NC} $1"
# }

# print_error() {
#     echo -e "${RED}[ERROR]${NC} $1"
# }

# print_warning() {
#     echo -e "${YELLOW}[WARNING]${NC} $1"
# }

# # Function to wait for service health check
# wait_for_service() {
#     local container_name=$1
#     local port=$2
#     local max_attempts=30
#     local attempt=0

#     print_status "Waiting for $container_name to be ready..."
    
#     while [ $attempt -lt $max_attempts ]; do
#         if podman exec "$container_name" true &>/dev/null; then
#             if [ -z "$port" ] || nc -z localhost "$port" &>/dev/null || podman exec "$container_name" sh -c "echo > /dev/tcp/127.0.0.1/$port" &>/dev/null; then
#                 print_status "$container_name is ready"
#                 return 0
#             fi
#         fi
#         attempt=$((attempt + 1))
#         sleep 1
#     done
    
#     print_error "Timeout waiting for $container_name"
#     return 1
# }

# # Step 1: Create Podman network
# print_status "Creating Podman network '$NETWORK_NAME'..."
# podman network create "$NETWORK_NAME" 2>/dev/null || print_warning "Network already exists"

# # Step 2: Start database and message queue containers
# print_status "Starting database and message queue services..."

# # MySQL
# print_status "Starting MySQL..."
# podman run -d \
#     --name mysql-service \
#     --network "$NETWORK_NAME" \
#     -e MYSQL_ROOT_PASSWORD=rootpassword \
#     -e MYSQL_DATABASE=eventdb \
#     -v mysql-data:/var/lib/mysql \
#     --health-cmd="mysqladmin ping -h localhost" \
#     --health-interval=10s \
#     --health-timeout=5s \
#     --health-retries=5 \
#     mysql:8.0 || print_warning "MySQL container already exists"

# wait_for_service "mysql-service" 3306

# # PostgreSQL
# print_status "Starting PostgreSQL..."
# podman run -d \
#     --name postgres-service \
#     --network "$NETWORK_NAME" \
#     -e POSTGRES_USER=authuser \
#     -e POSTGRES_PASSWORD=authpassword \
#     -e POSTGRES_DB=authdb \
#     -v postgres-data:/var/lib/postgresql/data \
#     --health-cmd="pg_isready -U authuser" \
#     --health-interval=10s \
#     --health-timeout=5s \
#     --health-retries=5 \
#     postgres:15 || print_warning "PostgreSQL container already exists"

# wait_for_service "postgres-service" 5433

# # MongoDB
# print_status "Starting MongoDB..."
# podman run -d \
#     --name mongodb-service \
#     --network "$NETWORK_NAME" \
#     -e MONGO_INITDB_ROOT_USERNAME=mongouser \
#     -e MONGO_INITDB_ROOT_PASSWORD=mongopassword \
#     -v mongodb-data:/data/db \
#     --health-cmd="mongosh --eval 'db.adminCommand(\"ping\")'" \
#     --health-interval=10s \
#     --health-timeout=5s \
#     --health-retries=5 \
#     mongo:6.0 || print_warning "MongoDB container already exists"

# wait_for_service "mongodb-service" 27017

# # Redis
# print_status "Starting Redis..."
# podman run -d \
#     --name redis-service \
#     --network "$NETWORK_NAME" \
#     -v redis-data:/data \
#     --health-cmd="redis-cli ping" \
#     --health-interval=10s \
#     --health-timeout=5s \
#     --health-retries=5 \
#     redis:7-alpine || print_warning "Redis container already exists"

# wait_for_service "redis-service" 6379

# # RabbitMQ
# print_status "Starting RabbitMQ..."
# podman run -d \
#     --name rabbitmq-service \
#     --network "$NETWORK_NAME" \
#     -e RABBITMQ_DEFAULT_USER=rabbitmquser \
#     -e RABBITMQ_DEFAULT_PASS=rabbitmqpassword \
#     -v rabbitmq-data:/var/lib/rabbitmq \
#     --health-cmd="rabbitmq-diagnostics -q ping" \
#     --health-interval=10s \
#     --health-timeout=5s \
#     --health-retries=5 \
#     rabbitmq:3.12-management-alpine || print_warning "RabbitMQ container already exists"

# wait_for_service "rabbitmq-service" 5672

# # Step 3: Build service images
# print_status "Building service images..."

# SERVICES=("auth-service" "order-service" "payment-service" "notification-service" "analytics-service-python" "dashboard-frontend")

# for service in "${SERVICES[@]}"; do
#     SERVICE_PATH="$PROJECT_ROOT/services/$service"
#     if [ -f "$SERVICE_PATH/Containerfile" ]; then
#         print_status "Building $service..."
#         podman build -t "$service:latest" -f "$SERVICE_PATH/Containerfile" "$SERVICE_PATH"
#     else
#         print_warning "Containerfile not found for $service"
#     fi
# done

# # Step 4: Start service containers
# print_status "Starting service containers..."

# # Auth Service (PostgreSQL)
# print_status "Starting Auth Service..."
# podman run -d \
#     --name auth-service \
#     --network "$NETWORK_NAME" \
#     -e PGHOST=postgres-service \
#     -e PGUSER=authuser \
#     -e PGPASSWORD=authpassword \
#     -e PGDATABASE=authdb \
#     -e PGPORT=5432 \
#     --health-cmd="curl -f http://localhost:3001/health || exit 1" \
#     --health-interval=10s \
#     --health-timeout=5s \
#     --health-retries=5 \
#     -p 3001:3001 \
#     auth-service:latest || print_warning "Auth service already running"

# wait_for_service "auth-service" 3001

# # Order Service (MySQL)
# print_status "Starting Order Service..."
# podman run -d \
#     --name order-service \
#     --network "$NETWORK_NAME" \
#     -e DB_HOST=mysql-service \
#     -e DB_USER=root \
#     -e DB_PASSWORD=rootpassword \
#     -e DB_NAME=eventdb \
#     -e DB_PORT=3306 \
#     -e RABBITMQ_HOST=rabbitmq-service \
#     -e RABBITMQ_USER=rabbitmquser \
#     -e RABBITMQ_PASSWORD=rabbitmqpassword \
#     --health-cmd="curl -f http://localhost:3002/health || exit 1" \
#     --health-interval=10s \
#     --health-timeout=5s \
#     --health-retries=5 \
#     -p 3002:3002 \
#     order-service:latest || print_warning "Order service already running"

# wait_for_service "order-service" 3002

# # Payment Service (MongoDB)
# print_status "Starting Payment Service..."
# podman run -d \
#     --name payment-service \
#     --network "$NETWORK_NAME" \
#     -e MONGO_HOST=mongodb-service \
#     -e MONGO_USER=mongouser \
#     -e MONGO_PASSWORD=mongopassword \
#     -e MONGO_DB=paymentdb \
#     -e MONGO_PORT=27017 \
#     --health-cmd="curl -f http://localhost:3003/health || exit 1" \
#     --health-interval=10s \
#     --health-timeout=5s \
#     --health-retries=5 \
#     -p 3003:3003 \
#     payment-service:latest || print_warning "Payment service already running"

# wait_for_service "payment-service" 3003

# # Notification Service (RabbitMQ)
# print_status "Starting Notification Service..."
# podman run -d \
#     --name notification-service \
#     --network "$NETWORK_NAME" \
#     -e RABBITMQ_HOST=rabbitmq-service \
#     -e RABBITMQ_USER=rabbitmquser \
#     -e RABBITMQ_PASSWORD=rabbitmqpassword \
#     --health-cmd="curl -f http://localhost:3004/health || exit 1" \
#     --health-interval=10s \
#     --health-timeout=5s \
#     --health-retries=5 \
#     -p 3004:3004 \
#     notification-service:latest || print_warning "Notification service already running"

# wait_for_service "notification-service" 3004

# # Analytics Service (Python API)
# print_status "Starting Analytics Service..."
# podman run -d \
#     --name analytics-service \
#     --network "$NETWORK_NAME" \
#     -e REDIS_HOST=redis-service \
#     -e REDIS_PORT=6379 \
#     -e MONGO_HOST=mongodb-service \
#     -e MONGO_USER=mongouser \
#     -e MONGO_PASSWORD=mongopassword \
#     --health-cmd="curl -f http://localhost:3005/health || exit 1" \
#     --health-interval=10s \
#     --health-timeout=5s \
#     --health-retries=5 \
#     -p 3005:3005 \
#     analytics-service-python:latest python app/main.py || print_warning "Analytics service already running"

# wait_for_service "analytics-service" 3005

# # Dashboard Frontend
# print_status "Starting Dashboard Frontend..."
# podman run -d \
#     --name dashboard-frontend \
#     --network "$NETWORK_NAME" \
#     -e REACT_APP_API_URL=http://localhost:3005 \
#     --health-cmd="curl -f http://localhost:3000/ || exit 1" \
#     --health-interval=10s \
#     --health-timeout=5s \
#     --health-retries=5 \
#     -p 3000:3000 \
#     dashboard-frontend:latest || print_warning "Dashboard frontend already running"

# wait_for_service "dashboard-frontend" 3000

# # Step 6: Run analytics job
# print_status "Running analytics job..."
# podman run --rm \
#     --network "$NETWORK_NAME" \
#     -e REDIS_HOST=redis-service \
#     -e REDIS_PORT=6379 \
#     -e MONGO_HOST=mongodb-service \
#     -e MONGO_USER=mongouser \
#     -e MONGO_PASSWORD=mongopassword \
#     analytics-service-python:latest python job.py || print_warning "Analytics job failed"

# print_status "All services started successfully!"
# echo -e "${GREEN}=== Setup Complete ===${NC}"
# echo ""
# echo "Services are running at:"
# echo "  - Auth Service: http://localhost:3001"
# echo "  - Order Service: http://localhost:3002"
# echo "  - Payment Service: http://localhost:3003"
# echo "  - Notification Service: http://localhost:3004"
# echo "  - Analytics Service: http://localhost:3005"
# echo "  - Dashboard: http://localhost:3000"
# echo ""
# echo "To view logs: podman logs <container-name>"
# echo "To stop all services: podman stop auth-service order-service payment-service notification-service analytics-service dashboard-frontend"
# echo "To remove all services: podman rm auth-service order-service payment-service notification-service analytics-service dashboard-frontend mysql-service postgres-service mongodb-service redis-service rabbitmq-service"
# echo "To remove network: podman network rm $NETWORK_NAME"
