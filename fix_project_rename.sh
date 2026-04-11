#!/bin/bash
# Script to rename "Flex Earnings Tracker" → "BlockErrn" across the entire project.
# Run this AFTER closing Xcode, from the project root directory.
# Usage: cd ~/Desktop/"Flex Earnings Tracker" && bash fix_project_rename.sh

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
PBXPROJ="$PROJECT_ROOT/Flex Earnings Tracker.xcodeproj/project.pbxproj"
SCHEME1="$PROJECT_ROOT/Flex Earnings Tracker.xcodeproj/xcshareddata/xcschemes/BlockErrn.xcscheme"
SCHEME2="$PROJECT_ROOT/Flex Earnings Tracker.xcodeproj/xcshareddata/xcschemes/BlockErrnWidgetsExtension.xcscheme"
SCHEMEMGMT="$PROJECT_ROOT/Flex Earnings Tracker.xcodeproj/xcuserdata/tejayguilliams.xcuserdatad/xcschemes/xcschememanagement.plist"

echo "=== BlockErrn Project Rename Script ==="
echo "Project root: $PROJECT_ROOT"
echo ""

# Safety check: make sure Xcode isn't running with this project
if pgrep -f "Xcode" > /dev/null 2>&1; then
    echo "WARNING: Xcode appears to be running. Please close Xcode first!"
    echo "Press Enter to continue anyway, or Ctrl+C to abort..."
    read -r
fi

# ──────────────────────────────────────────────────
# Step 1: Fix project.pbxproj
# ──────────────────────────────────────────────────
echo "Step 1: Fixing project.pbxproj..."

# 1a. Remove the broken PBXBuildFile entries (folder refs added to Resources)
sed -i '' '/D1271B022F89C07F00D0EA96.*BlockErrn in Resources/d' "$PBXPROJ"
sed -i '' '/D1271B042F89C08500D0EA96.*BlockErrnUITests in Resources/d' "$PBXPROJ"
sed -i '' '/D1271B062F89C08C00D0EA96.*BlockErrnTests in Resources/d' "$PBXPROJ"

# 1b. Remove the broken PBXFileReference entries (folder refs)
sed -i '' '/D1271B012F89C07F00D0EA96.*lastKnownFileType = folder.*BlockErrn/d' "$PBXPROJ"
sed -i '' '/D1271B032F89C08500D0EA96.*lastKnownFileType = folder.*BlockErrnUITests/d' "$PBXPROJ"
sed -i '' '/D1271B052F89C08C00D0EA96.*lastKnownFileType = folder.*BlockErrnTests/d' "$PBXPROJ"

# 1c. Remove the broken references from the main group's children list
sed -i '' '/D1271B012F89C07F00D0EA96.*BlockErrn \*\//d' "$PBXPROJ"
sed -i '' '/D1271B032F89C08500D0EA96.*BlockErrnUITests/d' "$PBXPROJ"
sed -i '' '/D1271B052F89C08C00D0EA96.*BlockErrnTests/d' "$PBXPROJ"

# 1d. Remove the broken entries from the Resources build phase
sed -i '' '/D1271B062F89C08C00D0EA96.*BlockErrnTests in Resources/d' "$PBXPROJ"
sed -i '' '/D1271B022F89C07F00D0EA96.*BlockErrn in Resources/d' "$PBXPROJ"
sed -i '' '/D1271B042F89C08500D0EA96.*BlockErrnUITests in Resources/d' "$PBXPROJ"

# 1e. Add back proper PBXFileSystemSynchronizedRootGroup entries for the source folders
# We need to insert these in the PBXFileSystemSynchronizedRootGroup section
# Use the original IDs from before they were removed
sed -i '' '/^\/\* End PBXFileSystemSynchronizedRootGroup section \*\//i\
\t\tD19631142F72C37700766B99 /* BlockErrn */ = {\
\t\t\tisa = PBXFileSystemSynchronizedRootGroup;\
\t\t\tpath = BlockErrn;\
\t\t\tsourceTree = "<group>";\
\t\t};\
\t\tD19631222F72C37800766B99 /* BlockErrnTests */ = {\
\t\t\tisa = PBXFileSystemSynchronizedRootGroup;\
\t\t\tpath = BlockErrnTests;\
\t\t\tsourceTree = "<group>";\
\t\t};\
\t\tD196312C2F72C37800766B99 /* BlockErrnUITests */ = {\
\t\t\tisa = PBXFileSystemSynchronizedRootGroup;\
\t\t\tpath = BlockErrnUITests;\
\t\t\tsourceTree = "<group>";\
\t\t};
' "$PBXPROJ"

# 1f. Add the root groups back to the main group children list
# Insert after the BlockErrn-Info.plist line
sed -i '' '/D1BB9EEA2F74B52A0072981D.*BlockErrn-Info.plist/a\
\t\t\t\tD19631142F72C37700766B99 /* BlockErrn */,\
\t\t\t\tD19631222F72C37800766B99 /* BlockErrnTests */,\
\t\t\t\tD196312C2F72C37800766B99 /* BlockErrnUITests */,
' "$PBXPROJ"

# 1g. Add fileSystemSynchronizedGroups to the BlockErrn target
# Insert after the empty dependencies list in the BlockErrn target
sed -i '' '/name = BlockErrn;/{
N
/packageProductDependencies/i\
\t\t\tfileSystemSynchronizedGroups = (\
\t\t\t\tD19631142F72C37700766B99 /* BlockErrn */,\
\t\t\t);
}' "$PBXPROJ"

# 1h. Add fileSystemSynchronizedGroups to BlockErrnTests target
sed -i '' '/name = BlockErrnTests;/{
N
/packageProductDependencies/i\
\t\t\tfileSystemSynchronizedGroups = (\
\t\t\t\tD19631222F72C37800766B99 /* BlockErrnTests */,\
\t\t\t);
}' "$PBXPROJ"

# 1i. Add fileSystemSynchronizedGroups to BlockErrnUITests target
sed -i '' '/name = BlockErrnUITests;/{
N
/packageProductDependencies/i\
\t\t\tfileSystemSynchronizedGroups = (\
\t\t\t\tD196312C2F72C37800766B99 /* BlockErrnUITests */,\
\t\t\t);
}' "$PBXPROJ"

# 1j. Update CODE_SIGN_ENTITLEMENTS paths
sed -i '' 's|"Flex Earnings Tracker/BackgroundModes.entitlements"|"BlockErrn/BackgroundModes.entitlements"|g' "$PBXPROJ"

# 1k. Update the project name in PBXProject build configuration list comment
sed -i '' 's|PBXProject "Flex Earnings Tracker"|PBXProject "BlockErrn"|g' "$PBXPROJ"

echo "  project.pbxproj updated."

# ──────────────────────────────────────────────────
# Step 2: Rename physical folders
# ──────────────────────────────────────────────────
echo "Step 2: Renaming physical folders..."

# Rename nested subfolder first (if it exists)
if [ -d "$PROJECT_ROOT/Flex Earnings Tracker/Flex Earnings Tracker" ]; then
    mv "$PROJECT_ROOT/Flex Earnings Tracker/Flex Earnings Tracker" "$PROJECT_ROOT/Flex Earnings Tracker/BlockErrn"
    echo "  Renamed nested subfolder"
fi

# Rename main source folder
if [ -d "$PROJECT_ROOT/Flex Earnings Tracker" ] && [ ! -d "$PROJECT_ROOT/BlockErrn" ]; then
    mv "$PROJECT_ROOT/Flex Earnings Tracker" "$PROJECT_ROOT/BlockErrn"
    echo "  Renamed Flex Earnings Tracker/ → BlockErrn/"
else
    echo "  Main source folder already renamed or doesn't exist, skipping"
fi

# Rename test folders
if [ -d "$PROJECT_ROOT/Flex Earnings TrackerTests" ]; then
    mv "$PROJECT_ROOT/Flex Earnings TrackerTests" "$PROJECT_ROOT/BlockErrnTests"
    echo "  Renamed Flex Earnings TrackerTests/ → BlockErrnTests/"
else
    echo "  Test folder already renamed, skipping"
fi

if [ -d "$PROJECT_ROOT/Flex Earnings TrackerUITests" ]; then
    mv "$PROJECT_ROOT/Flex Earnings TrackerUITests" "$PROJECT_ROOT/BlockErrnUITests"
    echo "  Renamed Flex Earnings TrackerUITests/ → BlockErrnUITests/"
else
    echo "  UI test folder already renamed, skipping"
fi

# ──────────────────────────────────────────────────
# Step 3: Update scheme files
# ──────────────────────────────────────────────────
echo "Step 3: Updating scheme files..."

# The xcodeproj is about to be renamed, so update container references
# to use the new name
sed -i '' 's|container:Flex Earnings Tracker.xcodeproj|container:BlockErrn.xcodeproj|g' "$SCHEME1"
sed -i '' 's|../../Flex Earnings Tracker/BlockErrnProducts.storekit|../../BlockErrn/BlockErrnProducts.storekit|g' "$SCHEME1"
sed -i '' 's|container:Flex Earnings Tracker.xcodeproj|container:BlockErrn.xcodeproj|g' "$SCHEME2"

echo "  Scheme files updated."

# ──────────────────────────────────────────────────
# Step 4: Update xcschememanagement.plist
# ──────────────────────────────────────────────────
echo "Step 4: Updating xcschememanagement.plist..."
sed -i '' 's|Flex Earnings Tracker.xcscheme_^#shared#^_|BlockErrn.xcscheme_^#shared#^_|g' "$SCHEMEMGMT"
echo "  xcschememanagement.plist updated."

# ──────────────────────────────────────────────────
# Step 5: Rename .xcodeproj directory
# ──────────────────────────────────────────────────
echo "Step 5: Renaming .xcodeproj directory..."
if [ -d "$PROJECT_ROOT/Flex Earnings Tracker.xcodeproj" ]; then
    mv "$PROJECT_ROOT/Flex Earnings Tracker.xcodeproj" "$PROJECT_ROOT/BlockErrn.xcodeproj"
    echo "  Renamed Flex Earnings Tracker.xcodeproj → BlockErrn.xcodeproj"
else
    echo "  .xcodeproj already renamed, skipping"
fi

# ──────────────────────────────────────────────────
# Step 6: Clean derived data
# ──────────────────────────────────────────────────
echo "Step 6: Cleaning derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/Flex_Earnings_Tracker-*
echo "  Derived data cleaned."

echo ""
echo "=== DONE ==="
echo ""
echo "To open the project:"
echo "  open \"$PROJECT_ROOT/BlockErrn.xcodeproj\""
echo ""
echo "After opening, do a Clean Build (Cmd+Shift+K) then Build (Cmd+B)."
