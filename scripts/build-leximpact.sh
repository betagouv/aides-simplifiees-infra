#!/bin/bash
set -e

echo "Building multi-platform LexImpact Territoires Docker image..."
echo "Target: ghcr.io/betagouv/leximpact-territoires:latest"
echo "Platforms: linux/amd64, linux/arm64"
echo ""

# Check if territoires repository exists
if [ ! -d "../territoires" ]; then
    echo "Cloning territoires repository..."
    git clone https://git.leximpact.dev/leximpact/territoires/territoires.git ../territoires
fi

# Build multi-platform image
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -f dockerfiles/leximpact.Dockerfile \
  -t ghcr.io/betagouv/leximpact-territoires:latest \
  --push \
  ../territoires

echo ""
echo "Build and push completed successfully!"
echo "Image available at: ghcr.io/betagouv/leximpact-territoires:latest"