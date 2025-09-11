#!/bin/bash

# Health check script for Aides Simplifiées infrastructure
# This script checks the health of all services

set -e

echo "Aides Simplifiées Infrastructure Health Check"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load monitoring secret if available
MONITORING_SECRET=""
if [ -f "./secrets/monitoring_secret" ]; then
    MONITORING_SECRET=$(cat ./secrets/monitoring_secret)
    echo "Monitoring secret loaded for authenticated health checks"
else
    echo -e "${YELLOW}Warning: monitoring secret not found, health checks may fail${NC}"
fi

# Function to check service health
check_service() {
    local service=$1
    local url=$2
    local expected_status=${3:-200}
    local use_monitoring_secret=${4:-false}
    
    echo -n "Checking $service... "
    
    local curl_cmd="curl -s -o /dev/null -w \"%{http_code}\""
    if [ "$use_monitoring_secret" = "true" ] && [ -n "$MONITORING_SECRET" ]; then
        curl_cmd="curl -s -o /dev/null -w \"%{http_code}\" -H \"x-monitoring-secret: $MONITORING_SECRET\""
    fi
    
    local status_code=$(eval "$curl_cmd \"$url\"" 2>/dev/null)
    if echo "$status_code" | grep -E "^(200|404|500)$" > /dev/null; then
        if [ "$status_code" = "500" ]; then
            echo -e "${YELLOW}REACHABLE (500 - app issue)${NC}"
        else
            echo -e "${GREEN}OK${NC}"
        fi
        return 0
    else
        echo -e "${RED}FAILED (status: $status_code)${NC}"
        return 1
    fi
}

# Function to check Docker service status
check_docker_service() {
    local service=$1
    echo -n "Checking Docker service $service... "
    
    local status=$(docker compose ps --services | grep "^$service$" > /dev/null && echo "running" || echo "not_running")
    if [ "$status" = "running" ]; then
        echo -e "${GREEN}RUNNING${NC}"
        return 0
    else
        echo -e "${RED}NOT RUNNING${NC}"
        return 1
    fi
}

echo "Docker Services Status:"
echo "-------------------------"

# Check Docker services
DOCKER_SERVICES=("nginx" "main-app" "db")
docker_status=0

for service in "${DOCKER_SERVICES[@]}"; do
    if ! check_docker_service "$service"; then
        docker_status=1
    fi
done

echo ""
echo "HTTP Health Checks:"
echo "----------------------"

# Check HTTP endpoints
http_status=0

# Check main application through nginx
if ! check_service "Main Application (HTTP)" "http://localhost:80"; then
    http_status=1
fi

# Check HTTPS (might fail with self-signed certs)
echo -n "Checking HTTPS endpoint... "
if curl -k -s -o /dev/null -w "%{http_code}" "https://localhost:443" | grep -q "200"; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${YELLOW}FAILED (might be expected with self-signed certs)${NC}"
fi

# Check health endpoint specifically
if ! check_service "Health Endpoint" "http://localhost:80/health" 200 true; then
    http_status=1
fi

# Check main-app directly (if port is exposed in dev mode)
if docker compose ps | grep "main-app" | grep "3333" > /dev/null; then
    if ! check_service "Main app Direct" "http://localhost:3333/health" 200 true; then
        http_status=1
    fi
fi

echo ""
echo "Database Status:"
echo "------------------"

# Check database connectivity
echo -n "Checking database connection... "
if docker compose exec -T db pg_isready -U aides-simplifiees > /dev/null 2>&1; then
    echo -e "${GREEN}OK${NC}"
    db_status=0
else
    echo -e "${RED}FAILED${NC}"
    db_status=1
fi

echo ""
echo "Summary:"
echo "----------"

overall_status=0

if [ $docker_status -eq 0 ]; then
    echo -e "Docker Services: ${GREEN}ALL RUNNING${NC}"
else
    echo -e "Docker Services: ${RED}SOME ISSUES${NC}"
    overall_status=1
fi

if [ $http_status -eq 0 ]; then
    echo -e "HTTP Endpoints: ${GREEN}ALL OK${NC}"
else
    echo -e "HTTP Endpoints: ${RED}SOME ISSUES${NC}"
    overall_status=1
fi

if [ $db_status -eq 0 ]; then
    echo -e "Database: ${GREEN}OK${NC}"
else
    echo -e "Database: ${RED}ISSUES${NC}"
    overall_status=1
fi

echo ""
if [ $overall_status -eq 0 ]; then
    echo -e "${GREEN}All systems operational!${NC}"
else
    echo -e "${RED}Some issues detected. Check logs with 'make logs'${NC}"
fi

echo ""
echo "Useful commands:"
echo "  make logs          - View all logs"
echo "  make status        - Check service status"
echo "  make nginx-test    - Test nginx configuration"
echo "  make restart       - Restart services"

exit $overall_status
