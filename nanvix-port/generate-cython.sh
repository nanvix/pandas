#!/bin/bash
# Generate C/C++ from Cython .pyx files for Nanvix cross-compilation.
# Run on HOST (not in Docker). Requires: cython, numpy, pandas source tree.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PANDAS_ROOT="$(dirname "$SCRIPT_DIR")"
LIBS="$PANDAS_ROOT/pandas/_libs"
OUTDIR="$SCRIPT_DIR/generated-c"
PXIDIR="$SCRIPT_DIR/generated-pxi"

mkdir -p "$OUTDIR" "$PXIDIR"

echo "=== Phase 1: Generating Tempita .pxi files ==="
TEMPITA="$PANDAS_ROOT/generate_pxi.py"
for tmpl in "$LIBS"/*.pxi.in; do
    base="$(basename "$tmpl" .pxi.in)"
    echo "  tempita: $base"
    python3 "$TEMPITA" "$tmpl" -o "$PXIDIR/"
done

echo "=== Phase 2: Cythonizing .pyx → .c/.cpp ==="

# Build a list of all modules with their Cython language
declare -A MODULES_CPP  # modules that need C++ output

# pandas/_libs/ modules
LIBS_MODULES=(
    algos arrays byteswap groupby hashing hashtable index indexing
    internals interval join lib missing ops ops_dispatch parsers
    properties reshape sas sparse testing tslib writers
)

# pandas/_libs/tslibs/ modules
TSLIBS_MODULES=(
    base ccalendar conversion dtypes fields nattype np_datetime
    offsets parsing period strptime timedeltas timestamps timezones
    tzconversion vectorized
)

# pandas/_libs/window/ modules
WINDOW_MODULES=(aggregations indexers)
MODULES_CPP[aggregations]=1  # C++ output

cythonize_module() {
    local pyx="$1"
    local modname="$2"
    local outfile="$3"
    local lang="${4:-c}"

    if [ "$lang" = "cpp" ]; then
        echo "  cython (C++): $modname"
        cython --fast-fail -3 -X always_allow_keywords=true \
            --include-dir "$PXIDIR" \
            --include-dir "$LIBS" \
            --module-name "$modname" \
            --cplus \
            -o "$outfile" "$pyx"
    else
        echo "  cython (C):   $modname"
        cython --fast-fail -3 -X always_allow_keywords=true \
            --include-dir "$PXIDIR" \
            --include-dir "$LIBS" \
            --module-name "$modname" \
            -o "$outfile" "$pyx"
    fi
}

for mod in "${LIBS_MODULES[@]}"; do
    pyx="$LIBS/$mod.pyx"
    out="$OUTDIR/${mod}.c"
    cythonize_module "$pyx" "pandas._libs.$mod" "$out"
done

for mod in "${TSLIBS_MODULES[@]}"; do
    pyx="$LIBS/tslibs/$mod.pyx"
    out="$OUTDIR/tslibs_${mod}.c"
    cythonize_module "$pyx" "pandas._libs.tslibs.$mod" "$out"
done

for mod in "${WINDOW_MODULES[@]}"; do
    pyx="$LIBS/window/$mod.pyx"
    if [[ -v "MODULES_CPP[$mod]" ]]; then
        out="$OUTDIR/window_${mod}.cpp"
        cythonize_module "$pyx" "pandas._libs.window.$mod" "$out" "cpp"
    else
        out="$OUTDIR/window_${mod}.c"
        cythonize_module "$pyx" "pandas._libs.window.$mod" "$out"
    fi
done

echo ""
echo "=== Generated files ==="
ls -la "$OUTDIR/"
echo ""
echo "Total C files: $(find "$OUTDIR" -name '*.c' | wc -l)"
echo "Total C++ files: $(find "$OUTDIR" -name '*.cpp' | wc -l)"
