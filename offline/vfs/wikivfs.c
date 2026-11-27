/* wikivfs: serve a read-only directory tree to PHP from one pack file.
 *
 * Paths under wikivfs.root (default /mw) are answered from the memory-mapped
 * pack named by wikivfs.pack (see pack.py for the format). Every other path
 * goes to PHP's own plain-files wrapper unchanged.
 *
 * How it hooks in:
 *  - it swaps the operations table of PHP's plain-files wrapper, so fopen,
 *    include, stat, opendir and friends all arrive here. The wrapper object
 *    itself stays the same one, because PHP special-cases its address: a
 *    stream that belongs to any other wrapper gets short reads from fread()
 *    (one 8 KiB chunk per call), which breaks callers that expect a file;
 *  - it wraps file_exists(), is_readable(), is_writable() and
 *    is_executable(), which for the plain-files wrapper call access(2)
 *    directly instead of asking the wrapper;
 *  - it replaces zend_resolve_path so include/require of a virtual path
 *    resolve without the real file system (and include_once sees one
 *    spelling per file);
 *  - it wraps realpath() for virtual paths.
 */
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif
#include "php.h"
#include "php_ini.h"
#include "SAPI.h"
#include "ext/standard/info.h"
#include "ext/standard/file.h"
#include "main/php_streams.h"
#include "Zend/zend_exceptions.h"
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

typedef struct {
	uint32_t path_off, path_len;
	uint64_t data_off, size;
	uint32_t flags, count;
} wv_entry;

typedef struct {
	char magic[8];
	uint32_t count, mtime;
	uint64_t strings_off, file_size;
} wv_header;

/* The pack: set once at module startup, read-only afterwards. */
static const char *wv_base;
static size_t wv_size;
static const wv_entry *wv_entries;
static const char *wv_strings;
static uint32_t wv_count, wv_mtime;
static char *wv_root;
static size_t wv_root_len;

/* Per-request profile. */
static struct {
	zend_long stat, stat_miss, open, open_miss, read, opendir, resolve, realpath, passthrough;
	uint64_t bytes, ns, start_ns;
} wv_prof;
static bool wv_profiling;

ZEND_BEGIN_MODULE_GLOBALS(wikivfs)
	char *pack;
	char *root;
	char *profile_log;
	char *trace_log;
ZEND_END_MODULE_GLOBALS(wikivfs)
ZEND_DECLARE_MODULE_GLOBALS(wikivfs)
#define WVG(v) ZEND_MODULE_GLOBALS_ACCESSOR(wikivfs, v)

static inline uint64_t wv_now(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
}
#define WV_T0 uint64_t wv_t0 = wv_profiling ? wv_now() : 0
#define WV_T1 do { if (wv_profiling) wv_prof.ns += wv_now() - wv_t0; } while (0)

/* Debugging aid: one line per open (O), stat hit (S) and stat miss (s). */
static void wv_trace(char what, const char *path)
{
	const char *log = WVG(trace_log);
	if (!log || !*log) return;
	FILE *f = fopen(log, "a");
	if (f) {
		fprintf(f, "%c %s\n", what, path);
		fclose(f);
	}
}

/* --- lookup ------------------------------------------------------------ */

static inline bool wv_is_virtual(const char *path)
{
	return wv_base && strncmp(path, wv_root, wv_root_len) == 0
		&& (path[wv_root_len] == '/' || path[wv_root_len] == 0);
}

static const wv_entry *wv_lookup(const char *path, zend_string **abs);

/* Strip file://, and take a relative path that exists under the root to mean
 * that file: MediaWiki assumes its install directory is the working
 * directory (it stores some paths relative to it), and the working directory
 * of the process cannot be a virtual one. buf must hold MAXPATHLEN bytes. */
static const char *wv_local(const char *path, char *buf)
{
	if (strncasecmp(path, "file://", 7) == 0) path += 7;
	if (wv_base && path[0] != '/' && path[0] != 0 && !strstr(path, "://")) {
		size_t n = strlen(path);
		if (wv_root_len + n + 2 < MAXPATHLEN) {
			memcpy(buf, wv_root, wv_root_len);
			buf[wv_root_len] = '/';
			memcpy(buf + wv_root_len + 1, path, n + 1);
			if (wv_lookup(buf, NULL)) return buf;
		}
	}
	return path;
}
#define wv_strip_scheme(path) wv_local((path), (char[MAXPATHLEN]){0})

/* Normalise the part of an absolute virtual path after the root into buf:
 * no leading or doubled slashes, "." and ".." resolved. Returns the length,
 * or -1 if the path climbs out of the root or does not fit. */
static ssize_t wv_normalize(const char *path, char *buf, size_t cap)
{
	const char *p = path + wv_root_len;
	size_t len = 0;
	while (*p) {
		while (*p == '/') p++;
		if (!*p) break;
		const char *seg = p;
		while (*p && *p != '/') p++;
		size_t n = (size_t)(p - seg);
		if (n == 1 && seg[0] == '.') continue;
		if (n == 2 && seg[0] == '.' && seg[1] == '.') {
			if (len == 0) return -1;
			while (len > 0 && buf[len - 1] != '/') len--;
			if (len > 0) len--;
			continue;
		}
		if (len + n + 2 > cap) return -1;
		if (len > 0) buf[len++] = '/';
		memcpy(buf + len, seg, n);
		len += n;
	}
	buf[len] = 0;
	return (ssize_t)len;
}

static const wv_entry *wv_find(const char *rel, size_t len)
{
	uint32_t lo = 0, hi = wv_count;
	while (lo < hi) {
		uint32_t mid = lo + (hi - lo) / 2;
		const wv_entry *e = &wv_entries[mid];
		size_t n = e->path_len < len ? e->path_len : len;
		int c = memcmp(wv_strings + e->path_off, rel, n);
		if (c == 0) c = e->path_len < len ? -1 : (e->path_len > len ? 1 : 0);
		if (c == 0) return e;
		if (c < 0) lo = mid + 1; else hi = mid;
	}
	return NULL;
}

/* Look up an absolute virtual path. If abs is given it receives the
 * normalised absolute path. */
static const wv_entry *wv_lookup(const char *path, zend_string **abs)
{
	char buf[MAXPATHLEN];
	ssize_t len = wv_normalize(path, buf, sizeof(buf));
	if (len < 0) return NULL;
	const wv_entry *e = wv_find(buf, (size_t)len);
	if (e && abs) {
		*abs = zend_string_alloc(wv_root_len + (len ? 1 + (size_t)len : 0), 0);
		memcpy(ZSTR_VAL(*abs), wv_root, wv_root_len);
		if (len) {
			ZSTR_VAL(*abs)[wv_root_len] = '/';
			memcpy(ZSTR_VAL(*abs) + wv_root_len + 1, buf, (size_t)len);
		}
		ZSTR_VAL(*abs)[ZSTR_LEN(*abs)] = 0;
	}
	return e;
}

static void wv_fill_stat(const wv_entry *e, php_stream_statbuf *ssb)
{
	memset(ssb, 0, sizeof(*ssb));
	ssb->sb.st_mode = (e->flags & 1) ? (S_IFDIR | 0555) : (S_IFREG | 0444);
	ssb->sb.st_size = (e->flags & 1) ? 0 : (zend_off_t)e->size;
	ssb->sb.st_nlink = 1;
	ssb->sb.st_ino = (ino_t)(e - wv_entries) + 1;
	ssb->sb.st_dev = 0x57564653;
	ssb->sb.st_mtime = ssb->sb.st_ctime = ssb->sb.st_atime = (time_t)wv_mtime;
	ssb->sb.st_blksize = 4096;
	ssb->sb.st_blocks = (e->size + 511) / 512;
}

/* --- file streams ------------------------------------------------------ */

typedef struct {
	const wv_entry *e;
	const char *data;
	size_t size, pos;
} wv_file;

static ssize_t wv_file_read(php_stream *stream, char *buf, size_t count)
{
	wv_file *f = stream->abstract;
	WV_T0;
	size_t left = f->size - f->pos;
	if (count > left) count = left;
	memcpy(buf, f->data + f->pos, count);
	f->pos += count;
	if (f->pos >= f->size) stream->eof = 1;
	wv_prof.read++;
	wv_prof.bytes += count;
	WV_T1;
	return (ssize_t)count;
}

static ssize_t wv_file_write(php_stream *stream, const char *buf, size_t count)
{
	return -1;
}

static int wv_file_close(php_stream *stream, int close_handle)
{
	efree(stream->abstract);
	return 0;
}

static int wv_file_flush(php_stream *stream)
{
	return 0;
}

static int wv_file_seek(php_stream *stream, zend_off_t offset, int whence, zend_off_t *newoffset)
{
	wv_file *f = stream->abstract;
	zend_off_t pos;
	switch (whence) {
		case SEEK_SET: pos = offset; break;
		case SEEK_CUR: pos = (zend_off_t)f->pos + offset; break;
		case SEEK_END: pos = (zend_off_t)f->size + offset; break;
		default: return -1;
	}
	if (pos < 0 || (size_t)pos > f->size) return -1;
	f->pos = (size_t)pos;
	stream->eof = 0;
	*newoffset = pos;
	return 0;
}

static int wv_file_stat(php_stream *stream, php_stream_statbuf *ssb)
{
	wv_fill_stat(((wv_file *)stream->abstract)->e, ssb);
	return 0;
}

static const php_stream_ops wv_file_ops = {
	wv_file_write, wv_file_read, wv_file_close, wv_file_flush,
	"wikivfs", wv_file_seek, NULL, wv_file_stat, NULL
};

/* --- directory streams ------------------------------------------------- */

typedef struct {
	const char *names, *next;
	uint32_t left, count;
} wv_dir;

static ssize_t wv_dir_read(php_stream *stream, char *buf, size_t count)
{
	wv_dir *d = stream->abstract;
	php_stream_dirent *ent = (php_stream_dirent *)buf;
	if (count != sizeof(php_stream_dirent) || d->left == 0) return -1;
	size_t n = strlen(d->next);
	memset(ent, 0, sizeof(*ent));
	if (n >= sizeof(ent->d_name)) n = sizeof(ent->d_name) - 1;
	memcpy(ent->d_name, d->next, n);
	d->next += strlen(d->next) + 1;
	d->left--;
	return sizeof(php_stream_dirent);
}

static int wv_dir_close(php_stream *stream, int close_handle)
{
	efree(stream->abstract);
	return 0;
}

static int wv_dir_rewind(php_stream *stream, zend_off_t offset, int whence, zend_off_t *newoffset)
{
	wv_dir *d = stream->abstract;
	d->next = d->names;
	d->left = d->count;
	return 0;
}

static const php_stream_ops wv_dir_ops = {
	NULL, wv_dir_read, wv_dir_close, NULL, "wikivfs dir", wv_dir_rewind, NULL, NULL, NULL
};

/* --- the wrapper ------------------------------------------------------- */

static const php_stream_wrapper_ops *wv_plain_ops;
#define WV_PLAIN wv_plain_ops
#define WV_PLAIN_W wrapper

static php_stream *wv_opener(php_stream_wrapper *wrapper, const char *path, const char *mode,
	int options, zend_string **opened_path, php_stream_context *context STREAMS_DC)
{
	const char *p = wv_strip_scheme(path);
	if (!wv_is_virtual(p)) {
		wv_prof.passthrough++;
		return WV_PLAIN->stream_opener(WV_PLAIN_W, path, mode, options, opened_path, context STREAMS_REL_CC);
	}
	WV_T0;
	php_stream *stream = NULL;
	wv_prof.open++;
	wv_trace('O', p);
	if (mode[0] != 'r' || strchr(mode, '+')) {
		errno = EROFS;
	} else {
		zend_string *abs = NULL;
		const wv_entry *e = wv_lookup(p, opened_path ? &abs : NULL);
		if (!e) {
			errno = ENOENT;
		} else if (e->flags & 1) {
			errno = EISDIR;
			if (abs) zend_string_release(abs);
		} else {
			wv_file *f = emalloc(sizeof(*f));
			f->e = e;
			f->data = wv_base + e->data_off;
			f->size = (size_t)e->size;
			f->pos = 0;
			stream = php_stream_alloc_rel(&wv_file_ops, f, NULL, "rb");
			stream->flags |= PHP_STREAM_FLAG_NO_BUFFER;
			if (opened_path) *opened_path = abs;
		}
	}
	if (!stream) {
		wv_prof.open_miss++;
		if (options & REPORT_ERRORS) {
			php_stream_wrapper_log_error(wrapper, options, "%s", strerror(errno));
		}
	}
	WV_T1;
	return stream;
}

static int wv_url_stat(php_stream_wrapper *wrapper, const char *url, int flags,
	php_stream_statbuf *ssb, php_stream_context *context)
{
	const char *p = wv_strip_scheme(url);
	if (!wv_is_virtual(p)) {
		wv_prof.passthrough++;
		return WV_PLAIN->url_stat(WV_PLAIN_W, url, flags, ssb, context);
	}
	WV_T0;
	const wv_entry *e = wv_lookup(p, NULL);
	wv_prof.stat++;
	wv_trace(e ? 'S' : 's', p);
	if (e) wv_fill_stat(e, ssb); else wv_prof.stat_miss++;
	WV_T1;
	return e ? 0 : -1;
}

static php_stream *wv_dir_opener(php_stream_wrapper *wrapper, const char *path, const char *mode,
	int options, zend_string **opened_path, php_stream_context *context STREAMS_DC)
{
	const char *p = wv_strip_scheme(path);
	if (!wv_is_virtual(p)) {
		wv_prof.passthrough++;
		return WV_PLAIN->dir_opener(WV_PLAIN_W, path, mode, options, opened_path, context STREAMS_REL_CC);
	}
	wv_prof.opendir++;
	const wv_entry *e = wv_lookup(p, NULL);
	if (!e || !(e->flags & 1)) {
		if (options & REPORT_ERRORS) {
			php_stream_wrapper_log_error(wrapper, options, "%s", strerror(e ? ENOTDIR : ENOENT));
		}
		return NULL;
	}
	wv_dir *d = emalloc(sizeof(*d));
	d->names = d->next = wv_base + e->data_off;
	d->left = d->count = e->count;
	return php_stream_alloc_rel(&wv_dir_ops, d, NULL, mode);
}

static int wv_read_only(php_stream_wrapper *wrapper, int options)
{
	if (options & REPORT_ERRORS) php_error_docref(NULL, E_WARNING, "wikivfs is read-only");
	return 0;
}

static int wv_unlink(php_stream_wrapper *wrapper, const char *url, int options, php_stream_context *context)
{
	if (wv_is_virtual(wv_strip_scheme(url))) return wv_read_only(wrapper, options);
	return WV_PLAIN->unlink(WV_PLAIN_W, url, options, context);
}

static int wv_rename(php_stream_wrapper *wrapper, const char *from, const char *to, int options, php_stream_context *context)
{
	if (wv_is_virtual(wv_strip_scheme(from)) || wv_is_virtual(wv_strip_scheme(to))) return wv_read_only(wrapper, options);
	return WV_PLAIN->rename(WV_PLAIN_W, from, to, options, context);
}

static int wv_mkdir(php_stream_wrapper *wrapper, const char *url, int mode, int options, php_stream_context *context)
{
	if (wv_is_virtual(wv_strip_scheme(url))) return wv_read_only(wrapper, options);
	return WV_PLAIN->stream_mkdir(WV_PLAIN_W, url, mode, options, context);
}

static int wv_rmdir(php_stream_wrapper *wrapper, const char *url, int options, php_stream_context *context)
{
	if (wv_is_virtual(wv_strip_scheme(url))) return wv_read_only(wrapper, options);
	return WV_PLAIN->stream_rmdir(WV_PLAIN_W, url, options, context);
}

static int wv_metadata(php_stream_wrapper *wrapper, const char *url, int options, void *value, php_stream_context *context)
{
	if (wv_is_virtual(wv_strip_scheme(url))) return 0;
	return WV_PLAIN->stream_metadata(WV_PLAIN_W, url, options, value, context);
}

static const php_stream_wrapper_ops wv_wrapper_ops = {
	wv_opener, NULL, NULL, wv_url_stat, wv_dir_opener, "wikivfs",
	wv_unlink, wv_rename, wv_mkdir, wv_rmdir, wv_metadata
};

/* --- path resolution --------------------------------------------------- */

static zend_string *(*wv_orig_resolve_path)(zend_string *filename);

static zend_string *wv_resolve_file(const char *abs_path)
{
	zend_string *abs = NULL;
	const wv_entry *e = wv_lookup(abs_path, &abs);
	if (e && !(e->flags & 1)) return abs;
	if (abs) zend_string_release(abs);
	return NULL;
}

static zend_string *wv_resolve_path(zend_string *filename)
{
	const char *name = ZSTR_VAL(filename);

	if (name[0] == '/') {
		if (!wv_is_virtual(name)) return wv_orig_resolve_path(filename);
		WV_T0;
		wv_prof.resolve++;
		zend_string *r = wv_resolve_file(name);
		WV_T1;
		return r;
	}

	/* A relative name: PHP looks along include_path and then next to the
	 * running script. Do the same for the virtual directories among them. */
	if (name[0] != '.' && !strstr(name, "://")) {
		char buf[MAXPATHLEN];
		const char *ip = PG(include_path);
		while (ip && *ip) {
			const char *end = strchr(ip, ':');
			size_t n = end ? (size_t)(end - ip) : strlen(ip);
			if (n + ZSTR_LEN(filename) + 2 < sizeof(buf) && n >= wv_root_len && wv_is_virtual(ip)) {
				memcpy(buf, ip, n);
				buf[n] = '/';
				memcpy(buf + n + 1, name, ZSTR_LEN(filename) + 1);
				if (wv_is_virtual(buf)) {
					zend_string *r = wv_resolve_file(buf);
					if (r) { wv_prof.resolve++; return r; }
				}
			}
			ip = end ? end + 1 : NULL;
		}
		if (zend_is_executing()) {
			zend_string *exec = zend_get_executed_filename_ex();
			if (exec && wv_is_virtual(ZSTR_VAL(exec))) {
				const char *slash = strrchr(ZSTR_VAL(exec), '/');
				size_t n = slash ? (size_t)(slash - ZSTR_VAL(exec)) : 0;
				if (n && n + ZSTR_LEN(filename) + 2 < sizeof(buf)) {
					memcpy(buf, ZSTR_VAL(exec), n);
					buf[n] = '/';
					memcpy(buf + n + 1, name, ZSTR_LEN(filename) + 1);
					zend_string *r = wv_resolve_file(buf);
					if (r) { wv_prof.resolve++; return r; }
				}
			}
		}
	}
	return wv_orig_resolve_path(filename);
}

/* realpath() asks the operating system directly, so wrap the function. */
static zif_handler wv_orig_realpath;

static PHP_FUNCTION(wikivfs_realpath)
{
	zend_string *path;
	if (ZEND_NUM_ARGS() == 1 && zend_parse_parameters(ZEND_NUM_ARGS(), "P", &path) == SUCCESS
		&& wv_is_virtual(ZSTR_VAL(path))) {
		zend_string *abs = NULL;
		wv_prof.realpath++;
		if (wv_lookup(ZSTR_VAL(path), &abs)) RETURN_STR(abs);
		RETURN_FALSE;
	}
	if (EG(exception)) zend_clear_exception();
	wv_orig_realpath(INTERNAL_FUNCTION_PARAM_PASSTHRU);
}

/* file_exists() and the is_*able() checks call access(2) for plain files. */
static zif_handler wv_orig_access[5];
static const char *const wv_access_names[5] = { "file_exists", "is_readable", "is_writable", "is_writeable", "is_executable" };

static void wv_access(INTERNAL_FUNCTION_PARAMETERS, int which)
{
	zend_string *path;
	if (ZEND_NUM_ARGS() == 1 && Z_TYPE_P(ZEND_CALL_ARG(execute_data, 1)) == IS_STRING) {
		path = Z_STR_P(ZEND_CALL_ARG(execute_data, 1));
		const char *p = wv_strip_scheme(ZSTR_VAL(path));
		if (wv_is_virtual(p) && strlen(ZSTR_VAL(path)) == ZSTR_LEN(path)) {
			WV_T0;
			const wv_entry *e = wv_lookup(p, NULL);
			wv_prof.stat++;
			if (!e) wv_prof.stat_miss++;
			wv_trace(e ? 'A' : 'a', p);
			WV_T1;
			switch (which) {
				case 0: case 1: RETURN_BOOL(e != NULL);
				case 4: RETURN_BOOL(e != NULL && (e->flags & 1));
				default: RETURN_FALSE; /* read-only */
			}
		}
	}
	wv_orig_access[which](INTERNAL_FUNCTION_PARAM_PASSTHRU);
}
static PHP_FUNCTION(wikivfs_file_exists) { wv_access(INTERNAL_FUNCTION_PARAM_PASSTHRU, 0); }
static PHP_FUNCTION(wikivfs_is_readable) { wv_access(INTERNAL_FUNCTION_PARAM_PASSTHRU, 1); }
static PHP_FUNCTION(wikivfs_is_writable) { wv_access(INTERNAL_FUNCTION_PARAM_PASSTHRU, 2); }
static PHP_FUNCTION(wikivfs_is_writeable) { wv_access(INTERNAL_FUNCTION_PARAM_PASSTHRU, 3); }
static PHP_FUNCTION(wikivfs_is_executable) { wv_access(INTERNAL_FUNCTION_PARAM_PASSTHRU, 4); }
static const zif_handler wv_access_handlers[5] = {
	ZEND_FN(wikivfs_file_exists), ZEND_FN(wikivfs_is_readable), ZEND_FN(wikivfs_is_writable),
	ZEND_FN(wikivfs_is_writeable), ZEND_FN(wikivfs_is_executable),
};

/* --- module ------------------------------------------------------------ */

PHP_INI_BEGIN()
	STD_PHP_INI_ENTRY("wikivfs.pack", "", PHP_INI_SYSTEM, OnUpdateString, pack, zend_wikivfs_globals, wikivfs_globals)
	STD_PHP_INI_ENTRY("wikivfs.root", "/mw", PHP_INI_SYSTEM, OnUpdateString, root, zend_wikivfs_globals, wikivfs_globals)
	STD_PHP_INI_ENTRY("wikivfs.trace_log", "", PHP_INI_SYSTEM, OnUpdateString, trace_log, zend_wikivfs_globals, wikivfs_globals)
	STD_PHP_INI_ENTRY("wikivfs.profile_log", "", PHP_INI_SYSTEM, OnUpdateString, profile_log, zend_wikivfs_globals, wikivfs_globals)
PHP_INI_END()

static PHP_MINIT_FUNCTION(wikivfs)
{
	REGISTER_INI_ENTRIES();

	const char *pack = WVG(pack);
	if (pack && *pack) {
		int fd = open(pack, O_RDONLY);
		struct stat st;
		if (fd < 0 || fstat(fd, &st) != 0 || (size_t)st.st_size < sizeof(wv_header)) {
			php_error_docref(NULL, E_CORE_WARNING, "wikivfs: cannot open pack %s", pack);
			if (fd >= 0) close(fd);
			return SUCCESS;
		}
		void *map = mmap(NULL, (size_t)st.st_size, PROT_READ, MAP_SHARED, fd, 0);
		close(fd);
		const wv_header *h = map;
		if (map == MAP_FAILED || memcmp(h->magic, "WVFS1\0\0", 8) != 0 || h->file_size > (uint64_t)st.st_size) {
			php_error_docref(NULL, E_CORE_WARNING, "wikivfs: %s is not a pack", pack);
			return SUCCESS;
		}
		wv_base = map;
		wv_size = (size_t)st.st_size;
		wv_count = h->count;
		wv_mtime = h->mtime;
		wv_entries = (const wv_entry *)(wv_base + sizeof(wv_header));
		wv_strings = wv_base + h->strings_off;
		wv_root = pestrdup(WVG(root), 1);
		wv_root_len = strlen(wv_root);
		while (wv_root_len > 1 && wv_root[wv_root_len - 1] == '/') wv_root[--wv_root_len] = 0;
	}

	if (!wv_base) return SUCCESS;

	wv_plain_ops = php_plain_files_wrapper.wops;
	php_plain_files_wrapper.wops = &wv_wrapper_ops;

	wv_orig_resolve_path = zend_resolve_path;
	zend_resolve_path = wv_resolve_path;

	for (int i = 0; i < 5; i++) {
		zend_function *f = zend_hash_str_find_ptr(CG(function_table), wv_access_names[i], strlen(wv_access_names[i]));
		if (f && f->type == ZEND_INTERNAL_FUNCTION) {
			wv_orig_access[i] = f->internal_function.handler;
			f->internal_function.handler = wv_access_handlers[i];
		}
	}

	zend_function *fn = zend_hash_str_find_ptr(CG(function_table), ZEND_STRL("realpath"));
	if (fn && fn->type == ZEND_INTERNAL_FUNCTION) {
		wv_orig_realpath = fn->internal_function.handler;
		fn->internal_function.handler = ZEND_FN(wikivfs_realpath);
	}
	return SUCCESS;
}

static PHP_MSHUTDOWN_FUNCTION(wikivfs)
{
	UNREGISTER_INI_ENTRIES();
	if (wv_base) {
		php_plain_files_wrapper.wops = wv_plain_ops;
		zend_resolve_path = wv_orig_resolve_path;
		munmap((void *)wv_base, wv_size);
	}
	return SUCCESS;
}

static PHP_RINIT_FUNCTION(wikivfs)
{
	if (!wv_base) return SUCCESS;
	memset(&wv_prof, 0, sizeof(wv_prof));
	wv_profiling = WVG(profile_log) && *WVG(profile_log);
	if (wv_profiling) wv_prof.start_ns = wv_now();
	return SUCCESS;
}

static PHP_RSHUTDOWN_FUNCTION(wikivfs)
{
	if (wv_base && wv_profiling) {
		FILE *f = fopen(WVG(profile_log), "a");
		if (f) {
			const char *uri = SG(request_info).request_uri ? SG(request_info).request_uri : "-";
			fprintf(f, "total_us=%llu vfs_us=%llu stat=%ld stat_miss=%ld open=%ld open_miss=%ld read=%ld bytes=%llu"
				" opendir=%ld resolve=%ld realpath=%ld passthrough=%ld uri=%s\n",
				(unsigned long long)((wv_now() - wv_prof.start_ns) / 1000), (unsigned long long)(wv_prof.ns / 1000),
				(long)wv_prof.stat, (long)wv_prof.stat_miss, (long)wv_prof.open, (long)wv_prof.open_miss,
				(long)wv_prof.read, (unsigned long long)wv_prof.bytes, (long)wv_prof.opendir,
				(long)wv_prof.resolve, (long)wv_prof.realpath, (long)wv_prof.passthrough, uri);
			fclose(f);
		}
	}
	return SUCCESS;
}

static PHP_MINFO_FUNCTION(wikivfs)
{
	php_info_print_table_start();
	php_info_print_table_row(2, "wikivfs", wv_base ? "pack loaded" : "no pack");
	php_info_print_table_end();
	DISPLAY_INI_ENTRIES();
}

zend_module_entry wikivfs_module_entry = {
	STANDARD_MODULE_HEADER,
	"wikivfs", NULL,
	PHP_MINIT(wikivfs), PHP_MSHUTDOWN(wikivfs), PHP_RINIT(wikivfs), PHP_RSHUTDOWN(wikivfs),
	PHP_MINFO(wikivfs), "0.1",
	PHP_MODULE_GLOBALS(wikivfs), NULL, NULL, NULL,
	STANDARD_MODULE_PROPERTIES_EX
};

ZEND_GET_MODULE(wikivfs)
