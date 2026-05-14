/*
 * Compatibility macros for numpy 2.x API when building against numpy 1.26.x.
 * Cython 3.x generates code using numpy 2.x function-style macros.
 * In numpy 1.26.x, these are struct field accesses.
 */
#ifndef _PANDAS_NUMPY_COMPAT_H
#define _PANDAS_NUMPY_COMPAT_H

#include "numpy/ndarraytypes.h"

/* numpy 2.x API → numpy 1.x struct access */
#ifndef PyDataType_ELSIZE
#define PyDataType_ELSIZE(d)      ((d)->elsize)
#endif
#ifndef PyDataType_ALIGNMENT
#define PyDataType_ALIGNMENT(d)   ((d)->alignment)
#endif
#ifndef PyDataType_FIELDS
#define PyDataType_FIELDS(d)      ((d)->fields)
#endif
#ifndef PyDataType_NAMES
#define PyDataType_NAMES(d)       ((d)->names)
#endif
#ifndef PyDataType_SUBARRAY
#define PyDataType_SUBARRAY(d)    ((d)->subarray)
#endif
#ifndef PyDataType_FLAGS
#define PyDataType_FLAGS(d)       ((d)->flags)
#endif

/* MultiIter accessors */
#ifndef PyArray_MultiIter_NUMITER
#define PyArray_MultiIter_NUMITER(o) (((PyArrayMultiIterObject *)(o))->numiter)
#endif
#ifndef PyArray_MultiIter_SIZE
#define PyArray_MultiIter_SIZE(o)    (((PyArrayMultiIterObject *)(o))->size)
#endif
#ifndef PyArray_MultiIter_INDEX
#define PyArray_MultiIter_INDEX(o)   (((PyArrayMultiIterObject *)(o))->index)
#endif
#ifndef PyArray_MultiIter_NDIM
#define PyArray_MultiIter_NDIM(o)    (((PyArrayMultiIterObject *)(o))->nd)
#endif
#ifndef PyArray_MultiIter_DIMS
#define PyArray_MultiIter_DIMS(o)    (((PyArrayMultiIterObject *)(o))->dimensions)
#endif
#ifndef PyArray_MultiIter_ITERS
#define PyArray_MultiIter_ITERS(o)   ((void **)(((PyArrayMultiIterObject *)(o))->iters))
#endif

#endif /* _PANDAS_NUMPY_COMPAT_H */
