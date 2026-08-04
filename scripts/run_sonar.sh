#!/bin/bash
# =============================================================================
# SonarQube Analysis Script for MEVI Dashboard
# Run this script to generate coverage and analyze code with SonarQube
# =============================================================================

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=============================================="
echo "🔍 MEVI Dashboard - SonarQube Analysis"
echo "=============================================="

# Step 1: Get dependencies
echo ""
echo "📦 Step 1/4: Getting dependencies..."
flutter pub get

# Step 2: Run analyzer
echo ""
echo "🔎 Step 2/4: Running Dart analyzer..."
flutter analyze --no-fatal-infos || true

# Step 3: Run tests with coverage
echo ""
echo "🧪 Step 3/4: Running tests with coverage..."
flutter test --coverage

# Check if coverage was generated
if [ -f "coverage/lcov.info" ]; then
    echo "✅ Coverage report generated: coverage/lcov.info"
    
    # Show basic coverage stats
    TOTAL_LINES=$(grep -c "DA:" coverage/lcov.info 2>/dev/null || echo "0")
    COVERED_LINES=$(grep "DA:" coverage/lcov.info | grep -v ",0$" | wc -l 2>/dev/null || echo "0")
    echo "   Total lines: $TOTAL_LINES"
    echo "   Covered lines: $COVERED_LINES"
else
    echo "⚠️ Warning: coverage/lcov.info not found"
fi

# Step 4: Run SonarScanner
echo ""
echo "📊 Step 4/4: Running SonarScanner..."

if command -v sonar-scanner &> /dev/null; then
    sonar-scanner
    echo ""
    echo "✅ SonarQube analysis complete!"
    echo "   Open your SonarQube dashboard to view results."
else
    echo "❌ sonar-scanner not found!"
    echo ""
    echo "Please install sonar-scanner:"
    echo "  - Arch Linux: yay -S sonar-scanner"
    echo "  - Manual: https://docs.sonarsource.com/sonarqube/latest/analyzing-source-code/scanners/sonarscanner/"
    echo ""
    echo "After installing, run this script again."
    exit 1
fi

echo ""
echo "=============================================="
echo "🎉 Done!"
echo "=============================================="
