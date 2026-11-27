/* What PHP's DllMain (win32/dllmain.c) does when php8.dll is loaded. In a
 * static build there is no DLL and DllMain never runs, so the same
 * initialisation is done here, before main(). Without it gettimeofday()
 * calls through a null pointer. Keep this in step with win32/dllmain.c.
 *
 * build.zig includes this at the end of the generated internal_functions.c:
 * a constructor in a file of its own would be dropped by the linker, because
 * nothing refers to it. */
#include "win32/time.h"
#include "win32/ioutil.h"

void php_win32_init_gettimeofday(void);

__attribute__((constructor))
static void php_static_process_attach(void)
{
	php_win32_init_gettimeofday();
	if (!php_win32_ioutil_init()) {
		fprintf(stderr, "ioutil initialization failed\n");
	}
}
