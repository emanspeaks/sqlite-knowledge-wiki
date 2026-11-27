/* Starts the embedded interpreter and runs PHP: the script named on the
 * command line, or with -r the code that follows. The output is the test
 * result. On a crash it prints a symbolised stack trace (the .pdb must be
 * next to the program). */
#include <sapi/embed/php_embed.h>

#ifdef _WIN32
#include <windows.h>
#include <dbghelp.h>

static LONG WINAPI on_crash(EXCEPTION_POINTERS *ep)
{
	DWORD code = ep->ExceptionRecord->ExceptionCode;
	switch (code) {
		case EXCEPTION_ACCESS_VIOLATION:
		case EXCEPTION_STACK_OVERFLOW:
		case EXCEPTION_ILLEGAL_INSTRUCTION:
		case EXCEPTION_INT_DIVIDE_BY_ZERO:
		case EXCEPTION_PRIV_INSTRUCTION:
		case EXCEPTION_IN_PAGE_ERROR:
		case EXCEPTION_ARRAY_BOUNDS_EXCEEDED:
		case 0xC0000409: /* stack buffer overrun / fail fast */
			break;
		default:
			return EXCEPTION_CONTINUE_SEARCH;
	}

	HANDLE process = GetCurrentProcess();
	fflush(stdout);
	fprintf(stderr, "\nCRASH: exception 0x%08lx at %p", code, ep->ExceptionRecord->ExceptionAddress);
	if (code == EXCEPTION_ACCESS_VIOLATION && ep->ExceptionRecord->NumberParameters >= 2) {
		fprintf(stderr, " (%s address %p)",
			ep->ExceptionRecord->ExceptionInformation[0] == 1 ? "writing" :
			ep->ExceptionRecord->ExceptionInformation[0] == 8 ? "executing" : "reading",
			(void *)ep->ExceptionRecord->ExceptionInformation[1]);
	}
	fprintf(stderr, "\n");

	SymSetOptions(SYMOPT_LOAD_LINES | SYMOPT_UNDNAME | SYMOPT_DEFERRED_LOADS);
	SymInitialize(process, NULL, TRUE);

	CONTEXT ctx = *ep->ContextRecord;
	STACKFRAME64 frame;
	memset(&frame, 0, sizeof frame);
	frame.AddrPC.Offset = ctx.Rip;
	frame.AddrPC.Mode = AddrModeFlat;
	frame.AddrFrame.Offset = ctx.Rbp;
	frame.AddrFrame.Mode = AddrModeFlat;
	frame.AddrStack.Offset = ctx.Rsp;
	frame.AddrStack.Mode = AddrModeFlat;

	char *base = (char *)GetModuleHandle(NULL);
	for (int i = 0; i < 48; i++) {
		if (!StackWalk64(IMAGE_FILE_MACHINE_AMD64, process, GetCurrentThread(), &frame, &ctx, NULL,
				SymFunctionTableAccess64, SymGetModuleBase64, NULL) || frame.AddrPC.Offset == 0) {
			break;
		}
		char buffer[sizeof(SYMBOL_INFO) + 512];
		SYMBOL_INFO *sym = (SYMBOL_INFO *)buffer;
		memset(sym, 0, sizeof(SYMBOL_INFO));
		sym->SizeOfStruct = sizeof(SYMBOL_INFO);
		sym->MaxNameLen = 511;
		DWORD64 displacement = 0;
		DWORD line_displacement = 0;
		IMAGEHLP_LINE64 line;
		memset(&line, 0, sizeof line);
		line.SizeOfStruct = sizeof line;
		fprintf(stderr, "  #%-2d +0x%llx", i, (unsigned long long)(frame.AddrPC.Offset - (DWORD64)base));
		if (SymFromAddr(process, frame.AddrPC.Offset, &displacement, sym)) {
			fprintf(stderr, " %s+0x%llx", sym->Name, (unsigned long long)displacement);
		}
		if (SymGetLineFromAddr64(process, frame.AddrPC.Offset, &line_displacement, &line)) {
			fprintf(stderr, " (%s:%lu)", line.FileName, line.LineNumber);
		}
		fprintf(stderr, "\n");
	}
	fflush(stderr);
	TerminateProcess(process, 3);
	return EXCEPTION_EXECUTE_HANDLER;
}
#endif

int main(int argc, char **argv)
{
	if (argc < 2 || (strcmp(argv[1], "-r") == 0 && argc < 3)) {
		fprintf(stderr, "usage: php-embed-smoke SCRIPT.php | -r CODE\n");
		return 2;
	}
#ifdef _WIN32
	AddVectoredExceptionHandler(1, on_crash);
#endif
	int status = 0;
	PHP_EMBED_START_BLOCK(argc, argv)
	if (strcmp(argv[1], "-r") == 0) {
		if (zend_eval_string(argv[2], NULL, "-r") != SUCCESS) status = 1;
	} else {
		zend_file_handle file;
		zend_stream_init_filename(&file, argv[1]);
		if (!php_execute_script(&file)) status = 1;
		zend_destroy_file_handle(&file);
	}
	status = status ? status : EG(exit_status);
	PHP_EMBED_END_BLOCK()
	return status;
}
