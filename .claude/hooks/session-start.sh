#!/bin/bash
set -euo pipefail

# Only run in remote Claude Code environments
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# ── 1. Swift ──────────────────────────────────────────────────────────────────
if command -v swift &> /dev/null; then
  echo "Swift $(swift --version 2>&1 | head -1) already installed"
else
  SWIFT_VERSION="6.0.3"
  TARBALL="swift-${SWIFT_VERSION}-RELEASE-ubuntu24.04.tar.gz"
  URL="https://download.swift.org/swift-${SWIFT_VERSION}-release/ubuntu2404/swift-${SWIFT_VERSION}-RELEASE/${TARBALL}"
  echo "Downloading Swift ${SWIFT_VERSION}..."
  curl -fSL "$URL" -o /tmp/${TARBALL}
  SWIFT_INSTALL_DIR="/opt/swift-${SWIFT_VERSION}"
  mkdir -p "$SWIFT_INSTALL_DIR"
  tar xzf /tmp/${TARBALL} -C "$SWIFT_INSTALL_DIR" --strip-components=1
  ln -sf "$SWIFT_INSTALL_DIR/usr/bin/swift"  /usr/local/bin/swift
  ln -sf "$SWIFT_INSTALL_DIR/usr/bin/swiftc" /usr/local/bin/swiftc
  rm /tmp/${TARBALL}
  echo "Done: $(swift --version 2>&1 | head -1)"
fi

# ── 2. SQLite with SQLITE_ENABLE_SNAPSHOT (required by GRDB) ─────────────────
# Ubuntu's libsqlite3 is not compiled with SQLITE_ENABLE_SNAPSHOT.
CUSTOM_SQLITE_MARKER="/usr/local/lib/libsqlite3-snapshot.marker"
if [ ! -f "$CUSTOM_SQLITE_MARKER" ]; then
  echo "Building SQLite with SQLITE_ENABLE_SNAPSHOT support..."
  SQLITE_VER_NUM="3450100"   # 3.45.1 — matches Ubuntu 24.04 package
  SQLITE_YEAR="2024"
  SQLITE_DIR="sqlite-amalgamation-${SQLITE_VER_NUM}"
  SQLITE_ZIP="${SQLITE_DIR}.zip"
  curl -fSL "https://www.sqlite.org/${SQLITE_YEAR}/${SQLITE_ZIP}" -o /tmp/${SQLITE_ZIP}
  unzip -q /tmp/${SQLITE_ZIP} -d /tmp/sqlite-src
  cd /tmp/sqlite-src/${SQLITE_DIR}
  # Compile with snapshot + FTS5 to match what GRDB expects
  gcc -O2 \
    -DSQLITE_ENABLE_SNAPSHOT \
    -DSQLITE_ENABLE_FTS5 \
    -DSQLITE_ENABLE_RTREE \
    -fPIC -c sqlite3.c -o sqlite3.o
  # Static library (preferred for SPM builds)
  ar rcs /usr/local/lib/libsqlite3.a sqlite3.o
  # Shared library
  gcc -O2 \
    -DSQLITE_ENABLE_SNAPSHOT \
    -DSQLITE_ENABLE_FTS5 \
    -DSQLITE_ENABLE_RTREE \
    -fPIC -shared sqlite3.c -o /usr/local/lib/libsqlite3.so.0.8.6
  ln -sf /usr/local/lib/libsqlite3.so.0.8.6 /usr/local/lib/libsqlite3.so.0
  ln -sf /usr/local/lib/libsqlite3.so.0      /usr/local/lib/libsqlite3.so
  cp sqlite3.h /usr/local/include/sqlite3.h
  ldconfig
  touch "$CUSTOM_SQLITE_MARKER"
  cd /tmp && rm -rf sqlite-src /tmp/${SQLITE_ZIP}
  echo "Custom SQLite built and installed to /usr/local/lib"
else
  echo "Custom SQLite already installed"
fi

# ── 3. Resolve Swift package dependencies ─────────────────────────────────────
echo "Resolving Swift package dependencies..."
cd "${CLAUDE_PROJECT_DIR}/GymTrackKit"
swift package resolve

echo "Session start hook complete."
