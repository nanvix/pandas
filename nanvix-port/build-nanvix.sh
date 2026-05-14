#!/bin/bash
# Cross-compile pandas C extensions for Nanvix (i686).
# Run inside Docker: ghcr.io/nanvix/toolchain-gcc:latest
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PANDAS_ROOT="$(dirname "$SCRIPT_DIR")"
LIBS="$PANDAS_ROOT/pandas/_libs"
GEN_C="$SCRIPT_DIR/generated-c"
OBJDIR="$PANDAS_ROOT/dist/obj"
DISTDIR="$PANDAS_ROOT/dist"

PY_INC="$SCRIPT_DIR/cpython-headers/python3.12"
NP_INC="$SCRIPT_DIR/numpy-headers"
PD_INC="$LIBS/include"
FF_INC="$SCRIPT_DIR/fast_float"

CC=i686-nanvix-gcc
CXX=i686-nanvix-g++
AR=i686-nanvix-ar

COMMON_FLAGS="-m32 -march=pentiumpro -Os -fdata-sections -ffunction-sections -DNDEBUG"
WARN_FLAGS="-Wno-unused-function -Wno-unused-variable -Wno-sign-compare \
  -Wno-unused-but-set-variable -Wno-missing-field-initializers \
  -Wno-unreachable-code -Wno-deprecated-declarations"
INC_FLAGS="-I$PY_INC -I$NP_INC -I$PD_INC -I$FF_INC -I$LIBS/src"

COMPAT_FLAGS="-include $SCRIPT_DIR/numpy-compat.h"
CFLAGS="$COMMON_FLAGS $WARN_FLAGS $INC_FLAGS $COMPAT_FLAGS -std=c11"
CXXFLAGS="$COMMON_FLAGS $WARN_FLAGS $INC_FLAGS $COMPAT_FLAGS -std=c++17"

rm -rf "$OBJDIR"
mkdir -p "$OBJDIR"

TOTAL=0
FAIL=0

compile_c() {
    local src="$1"
    local obj="$2"
    local extra="${3:-}"
    if $CC $CFLAGS $extra -c -o "$obj" "$src" 2>&1; then
        TOTAL=$((TOTAL + 1))
    else
        echo "FAILED: $src"
        FAIL=$((FAIL + 1))
    fi
}

compile_cpp() {
    local src="$1"
    local obj="$2"
    local extra="${3:-}"
    if $CXX $CXXFLAGS $extra -c -o "$obj" "$src" 2>&1; then
        TOTAL=$((TOTAL + 1))
    else
        echo "FAILED: $src"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Phase 1: Compile Cython-generated C files ==="
for cfile in "$GEN_C"/*.c; do
    base="$(basename "$cfile" .c)"
    echo "  CC $base.c"
    compile_c "$cfile" "$OBJDIR/${base}.o"
done

echo "=== Phase 2: Compile Cython-generated C++ files ==="
for cppfile in "$GEN_C"/*.cpp; do
    [ -f "$cppfile" ] || continue
    base="$(basename "$cppfile" .cpp)"
    echo "  CXX $base.cpp"
    compile_cpp "$cppfile" "$OBJDIR/${base}.o"
done

echo "=== Phase 3: Compile pure-C pandas sources ==="

# tokenizer.c (used by lib, parsers, pandas_parser, tslibs.parsing)
echo "  CC tokenizer.c"
compile_c "$LIBS/src/parser/tokenizer.c" "$OBJDIR/tokenizer.o"

# io.c
echo "  CC io.c"
compile_c "$LIBS/src/parser/io.c" "$OBJDIR/io.o"

# pd_parser.c
echo "  CC pd_parser.c"
compile_c "$LIBS/src/parser/pd_parser.c" "$OBJDIR/pd_parser.o"

# fast_float_strtod.cpp
echo "  CXX fast_float_strtod.cpp"
compile_cpp "$LIBS/src/parser/fast_float_strtod.cpp" "$OBJDIR/fast_float_strtod.o"

# vendored numpy datetime
echo "  CC np_datetime.c"
compile_c "$LIBS/src/vendored/numpy/datetime/np_datetime.c" "$OBJDIR/v_np_datetime.o"

echo "  CC np_datetime_strings.c"
compile_c "$LIBS/src/vendored/numpy/datetime/np_datetime_strings.c" "$OBJDIR/v_np_datetime_strings.o"

# pandas datetime
echo "  CC date_conversions.c"
compile_c "$LIBS/src/datetime/date_conversions.c" "$OBJDIR/date_conversions.o"

echo "  CC pd_datetime.c"
compile_c "$LIBS/src/datetime/pd_datetime.c" "$OBJDIR/pd_datetime.o"

# ujson
echo "  CC ujson.c"
compile_c "$LIBS/src/vendored/ujson/python/ujson.c" "$OBJDIR/ujson.o" \
  "-I$LIBS/src/vendored/ujson/lib -I$LIBS/src/vendored/ujson/python"

echo "  CC objToJSON.c"
compile_c "$LIBS/src/vendored/ujson/python/objToJSON.c" "$OBJDIR/objToJSON.o" \
  "-I$LIBS/src/vendored/ujson/lib -I$LIBS/src/vendored/ujson/python"

echo "  CC JSONtoObj.c"
compile_c "$LIBS/src/vendored/ujson/python/JSONtoObj.c" "$OBJDIR/JSONtoObj.o" \
  "-I$LIBS/src/vendored/ujson/lib -I$LIBS/src/vendored/ujson/python"

echo "  CC ultrajsonenc.c"
compile_c "$LIBS/src/vendored/ujson/lib/ultrajsonenc.c" "$OBJDIR/ultrajsonenc.o" \
  "-I$LIBS/src/vendored/ujson/lib"

echo "  CC ultrajsondec.c"
compile_c "$LIBS/src/vendored/ujson/lib/ultrajsondec.c" "$OBJDIR/ultrajsondec.o" \
  "-I$LIBS/src/vendored/ujson/lib"

echo "=== Phase 4: Create static archive ==="
$AR rcs "$DISTDIR/libpandas.a" "$OBJDIR"/*.o
echo "Archive: $(ls -lh "$DISTDIR/libpandas.a" | awk '{print $5}')"
echo "Objects: $(ls "$OBJDIR"/*.o | wc -l)"

echo ""
echo "=== Summary ==="
echo "Compiled: $TOTAL"
echo "Failed:   $FAIL"
if [ $FAIL -gt 0 ]; then
    echo "BUILD FAILED"
    exit 1
fi
echo "BUILD OK"
