/* The part of main/config.w32.h that does not depend on which optional
 * extensions are built.
 *
 * On Windows PHP's configure.js writes config.w32.h: the template
 * win32/build/config.w32.h.in followed by one define per enabled feature.
 * build.zig writes it the same way: this file, then each extension's lines. */
#include "win32/build/config.w32.h.in"

#define PHP_BUILD_SYSTEM "zig build"
#define PHP_BUILD_PROVIDER "sqlite-knowledge-wiki"
#define CONFIGURE_COMMAND "zig build"
#define PHP_BUILD_COMPILER "Zig (clang, MinGW-w64)"
#define PHP_COMPILER_ID "zig"
#define PHP_BUILD_ARCH "x64"
/* Not a Microsoft linker. PHP checks at startup that the Visual C++ runtime
 * DLL it finds loaded matches linker version 14; with any other value it
 * skips that check, which is right here: this build links Zig's C runtime
 * statically and loads no vcruntime140.dll. */
#define PHP_LINKER_MAJOR 0
#define PHP_LINKER_MINOR 0

#define HAVE_STRNLEN 1
#define ZEND_CHECK_STACK_LIMIT 1
#define HAVE_WSPIAPI_H 1
#define HAVE_GAI_STRERROR 1
#define HAVE_IPV6 1

/* ext/date */
#define HAVE_TIMELIB_CONFIG_H 1

/* ext/pcre, bundled PCRE2 */
#define HAVE_BUNDLED_PCRE 1
#define PCRE2_CODE_UNIT_WIDTH 8
#define PCRE2_STATIC 1

/* ext/standard */
#define PHP_CONFIG_FILE_SCAN_DIR ""
#define PHP_USE_PHP_CRYPT_R 1
