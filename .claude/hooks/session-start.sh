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
  echo "Swift not found — installing Swift 6.0.3..."

  # Strategy A: apt-get (works after apt-get update in some environments)
  SWIFT_INSTALLED=false
  if apt-get update -qq 2>/dev/null && apt-get install -y --no-install-recommends swiftlang 2>/dev/null; then
    SWIFT_INSTALLED=true
  fi

  if [ "$SWIFT_INSTALLED" = false ]; then
    # Strategy B: Download .deb packages directly from Ubuntu archive.
    # swiftlang 6.0.3 is in Ubuntu noble universe; libxml2-16 is a new
    # dependency that may not yet be in the local package index.
    echo "apt install failed — downloading .deb packages from Ubuntu archive..."
    UBUNTU_POOL="http://archive.ubuntu.com/ubuntu/pool"
    curl -fsSL "${UBUNTU_POOL}/main/libx/libxml2/libxml2-16_2.14.5+dfsg-0.2ubuntu0.1_amd64.deb" \
         -o /tmp/libxml2-16.deb
    curl -fsSL "${UBUNTU_POOL}/universe/s/swiftlang/libswiftlang_6.0.3-2build1_amd64.deb" \
         -o /tmp/libswiftlang.deb
    curl -fsSL "${UBUNTU_POOL}/universe/s/swiftlang/swiftlang_6.0.3-2build1_amd64.deb" \
         -o /tmp/swiftlang.deb
    dpkg -i /tmp/libxml2-16.deb /tmp/libswiftlang.deb /tmp/swiftlang.deb
    rm -f /tmp/libxml2-16.deb /tmp/libswiftlang.deb /tmp/swiftlang.deb
  fi

  echo "Done: $(swift --version 2>&1 | head -1)"
fi

# ── 2. SQLite with SQLITE_ENABLE_SNAPSHOT (required by GRDB) ─────────────────
# Ubuntu's libsqlite3 is not compiled with SQLITE_ENABLE_SNAPSHOT.
# We rebuild it and replace the system copies so Swift Package Manager's
# linker (which searches /usr/lib/x86_64-linux-gnu before /usr/local/lib)
# picks up the snapshot-enabled library.
CUSTOM_SQLITE_MARKER="/usr/local/lib/libsqlite3-snapshot.marker"
if [ ! -f "$CUSTOM_SQLITE_MARKER" ]; then
  echo "Building SQLite with SQLITE_ENABLE_SNAPSHOT support..."

  SQLITE_VER_NUM="3450100"   # 3.45.1 — matches Ubuntu 24.04 package
  SQLITE_YEAR="2024"
  AMALG_DIR="/tmp/sqlite-amalgamation"
  mkdir -p "$AMALG_DIR"

  # Strategy A: download amalgamation from sqlite.org (fast path, requires whitelist)
  SQLITE_ZIP="sqlite-amalgamation-${SQLITE_VER_NUM}.zip"
  if curl -fsSL "https://www.sqlite.org/${SQLITE_YEAR}/${SQLITE_ZIP}" \
          -o "/tmp/${SQLITE_ZIP}" 2>/dev/null; then
    unzip -q "/tmp/${SQLITE_ZIP}" -d /tmp/sqlite-amalgamation-src
    cp "/tmp/sqlite-amalgamation-src/sqlite-amalgamation-${SQLITE_VER_NUM}/sqlite3.c" "$AMALG_DIR/"
    cp "/tmp/sqlite-amalgamation-src/sqlite-amalgamation-${SQLITE_VER_NUM}/sqlite3.h" "$AMALG_DIR/"
    rm -rf /tmp/sqlite-amalgamation-src "/tmp/${SQLITE_ZIP}"
  else
    # Strategy B: generate the amalgamation from the Ubuntu source package.
    # archive.ubuntu.com is always accessible in remote Claude Code sessions.
    echo "sqlite.org not reachable — building from Ubuntu source package..."
    apt-get install -y --no-install-recommends tcl 2>/dev/null || true
    curl -fsSL "http://archive.ubuntu.com/ubuntu/pool/main/s/sqlite3/sqlite3_3.45.1.orig.tar.xz" \
         -o /tmp/sqlite3-src.tar.xz
    mkdir -p /tmp/sqlite3-src
    tar xf /tmp/sqlite3-src.tar.xz -C /tmp/sqlite3-src --strip-components=1
    (cd /tmp/sqlite3-src && ./configure --quiet && make sqlite3.c)
    cp /tmp/sqlite3-src/sqlite3.c "$AMALG_DIR/"
    cp /tmp/sqlite3-src/sqlite3.h "$AMALG_DIR/"
    rm -rf /tmp/sqlite3-src /tmp/sqlite3-src.tar.xz
  fi

  # Compile with snapshot + FTS5 + RTREE to match what GRDB expects
  cd "$AMALG_DIR"
  gcc -O2 \
      -DSQLITE_ENABLE_SNAPSHOT \
      -DSQLITE_ENABLE_FTS5 \
      -DSQLITE_ENABLE_RTREE \
      -fPIC -shared sqlite3.c -o libsqlite3.so.0.8.6
  gcc -O2 \
      -DSQLITE_ENABLE_SNAPSHOT \
      -DSQLITE_ENABLE_FTS5 \
      -DSQLITE_ENABLE_RTREE \
      -fPIC -c sqlite3.c -o sqlite3.o
  ar rcs libsqlite3.a sqlite3.o

  # Replace the system SQLite so the SPM linker (which searches
  # /usr/lib/x86_64-linux-gnu before /usr/local/lib) links the
  # snapshot-enabled build.
  ARCH_LIB="/usr/lib/x86_64-linux-gnu"
  RUNTIME_LIB="/lib/x86_64-linux-gnu"
  cp libsqlite3.so.0.8.6 "$ARCH_LIB/libsqlite3.so.0.8.6"
  cp libsqlite3.a         "$ARCH_LIB/libsqlite3.a"
  cp libsqlite3.so.0.8.6 "$RUNTIME_LIB/libsqlite3.so.0.8.6"
  cp libsqlite3.a         "$RUNTIME_LIB/libsqlite3.a"
  cp sqlite3.h            /usr/local/include/sqlite3.h
  ldconfig

  touch "$CUSTOM_SQLITE_MARKER"
  cd / && rm -rf "$AMALG_DIR"
  echo "Custom SQLite built and installed"
else
  echo "Custom SQLite already installed"
fi

# ── 3. Resolve Swift package dependencies ─────────────────────────────────────
echo "Resolving Swift package dependencies..."
cd "${CLAUDE_PROJECT_DIR}/GymTrackKit"
swift package resolve

echo "Session start hook complete."
