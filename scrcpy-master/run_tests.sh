#!/bin/bash
# Quick testing script for scrcpy delay optimization
# Usage: ./run_tests.sh [test_name]

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_DIR/builddir"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Scrcpy Quick Test Runner ===${NC}\n"

# Step 1: Setup or clean build
if [ ! -d "$BUILD_DIR" ]; then
    echo -e "${YELLOW}Setting up debug build environment...${NC}"
    meson setup "$BUILD_DIR" --buildtype=debug -Dbuildtype=debug
fi

# Step 2: Compile
echo -e "${YELLOW}Compiling tests...${NC}"
ninja -C "$BUILD_DIR" app/test_delay_buffer app/test_io_stream

# Step 3: Run tests
if [ -z "$1" ]; then
    # Run all tests
    echo -e "\n${BLUE}Running ALL tests...${NC}\n"
    meson test -C "$BUILD_DIR" test_delay_buffer test_io_stream --verbose
else
    # Run specific test
    echo -e "\n${BLUE}Running test: $1${NC}\n"
    meson test -C "$BUILD_DIR" "$1" --verbose
fi

echo -e "\n${GREEN}✓ Test execution complete!${NC}"
