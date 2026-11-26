/* ext/date/lib/timelib_config.h, as ext/date/config.w32 writes it. */
#include "config.w32.h"
#include <inttypes.h>
#include <stdint.h>
#include "zend.h"
#define timelib_malloc  emalloc
#define timelib_realloc erealloc
#define timelib_calloc  ecalloc
#define timelib_strdup  estrdup
#define timelib_strndup estrndup
#define timelib_free    efree
