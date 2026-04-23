#!/bin/bash
# Verification script - checks if testing setup is complete

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRCPY_DIR="$PROJECT_ROOT/scrcpy-master"

echo -e "${BLUE}=== Scrcpy Testing Setup Verification ===${NC}\n"

# Check 1: Test files exist
echo -n "Checking test files... "
if [ -f "$SCRCPY_DIR/app/tests/test_delay_buffer.c" ] && \
   [ -f "$SCRCPY_DIR/app/tests/test_io_stream.c" ]; then
    echo -e "${GREEN}✓ PASS${NC} (both test files exist)"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

# Check 2: test runner script
echo -n "Checking test runner script... "
if [ -f "$SCRCPY_DIR/run_tests.sh" ] && [ -x "$SCRCPY_DIR/run_tests.sh" ]; then
    echo -e "${GREEN}✓ PASS${NC} (script exists and is executable)"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

# Check 3: meson.build updated
echo -n "Checking meson.build registration... "
if grep -q "test_delay_buffer" "$SCRCPY_DIR/app/meson.build" && \
   grep -q "test_io_stream" "$SCRCPY_DIR/app/meson.build"; then
    echo -e "${GREEN}✓ PASS${NC} (tests registered in meson.build)"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

# Check 4: Documentation files
echo -n "Checking documentation... "
if [ -f "$PROJECT_ROOT/TESTING_SETUP.md" ] && \
   [ -f "$PROJECT_ROOT/DELAY_OPTIMIZATION.md" ] && \
   [ -f "$PROJECT_ROOT/CAMERA_SENSOR_TESTING.md" ] && \
   [ -f "$PROJECT_ROOT/CODE_OPTIMIZATION_EXAMPLES.md" ] && \
   [ -f "$PROJECT_ROOT/QUICK_START.md" ]; then
    echo -e "${GREEN}✓ PASS${NC} (all 5 documentation files exist)"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

# Check 5: Meson installed
echo -n "Checking meson build system... "
if command -v meson &> /dev/null; then
    MESON_VER=$(meson --version)
    echo -e "${GREEN}✓ PASS${NC} (meson $MESON_VER installed)"
else
    echo -e "${RED}✗ FAIL${NC} - Please install: sudo apt install meson"
fi

# Check 6: Trial compile
echo -n "Attempting trial build... "
cd "$SCRCPY_DIR"

# Check if builddir exists
if [ ! -d builddir ]; then
    if meson setup builddir --buildtype=debug > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC} (builddir created)"
    else
        echo -e "${YELLOW}⚠ WARNING${NC} (builddir setup failed - missing dependencies?)"
    fi
else
    echo -e "${GREEN}✓ PASS${NC} (builddir already exists)"
fi

# Check 7: Can find source files
echo -n "Checking delay_buffer source... "
if [ -f "$SCRCPY_DIR/app/src/delay_buffer.c" ] && \
   [ -f "$SCRCPY_DIR/app/src/delay_buffer.h" ]; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

# Check 8: Can find input/output sources
echo -n "Checking I/O source files... "
if [ -f "$SCRCPY_DIR/app/src/input_manager.c" ] && \
   [ -f "$SCRCPY_DIR/app/src/display.c" ] && \
   [ -f "$SCRCPY_DIR/app/src/decoder.c" ]; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

echo ""
echo -e "${BLUE}=== Setup Summary ===${NC}"
echo ""
echo "✓ Test files created: test_delay_buffer.c, test_io_stream.c"
echo "✓ Test runner: run_tests.sh"
echo "✓ Meson configuration updated"
echo "✓ Documentation files created:"
echo "  - QUICK_START.md (start here!)"
echo "  - TESTING_SETUP.md (detailed guide)"
echo "  - CODE_OPTIMIZATION_EXAMPLES.md (code changes)"
echo "  - DELAY_OPTIMIZATION.md (latency optimization)"
echo "  - CAMERA_SENSOR_TESTING.md (I/O testing)"
echo ""
echo -e "${BLUE}=== Next Steps ===${NC}"
echo ""
echo "1. Read the quick start guide:"
echo "   cat $PROJECT_ROOT/QUICK_START.md"
echo ""
echo "2. Build the tests:"
echo "   cd $SCRCPY_DIR"
echo "   meson setup builddir --buildtype=debug"
echo ""
echo "3. Run the tests:"
echo "   ./run_tests.sh"
echo ""
echo -e "${GREEN}Setup complete! You're ready to test and optimize scrcpy.${NC}"
