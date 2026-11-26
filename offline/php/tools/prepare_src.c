/* prepare_src: copy a source tree and apply unified diffs to the copy.
 *
 *   prepare_src SRC_DIR OUT_DIR [PATCH_FILE...]
 *
 * Used by build.zig so the vendored PHP sources are never modified in place:
 * the pristine release is copied into the build cache and the project's
 * patches are applied there.
 *
 * Patches are applied strictly: every hunk must match at the line it names,
 * with no offset and no fuzz. A patch that no longer applies fails the build
 * instead of landing somewhere unexpected.
 */
#include <dirent.h>
#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#ifdef _WIN32
# include <direct.h>
# define make_dir(p) _mkdir(p)
#else
# define make_dir(p) mkdir(p, 0777)
#endif

static void die(const char *fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);
	fputs("prepare_src: ", stderr);
	vfprintf(stderr, fmt, ap);
	fputc('\n', stderr);
	va_end(ap);
	exit(1);
}

static char *join(const char *a, const char *b)
{
	size_t la = strlen(a), lb = strlen(b);
	char *r = malloc(la + lb + 2);
	if (!r) die("out of memory");
	memcpy(r, a, la);
	r[la] = '/';
	memcpy(r + la + 1, b, lb + 1);
	return r;
}

static void make_dirs(const char *path)
{
	char *p = strdup(path);
	if (!p) die("out of memory");
	for (char *s = p + 1; *s; s++) {
		if (*s == '/' || *s == '\\') {
			char c = *s;
			*s = 0;
			make_dir(p);
			*s = c;
		}
	}
	if (make_dir(p) != 0 && errno != EEXIST) die("cannot create %s: %s", path, strerror(errno));
	free(p);
}

static char *read_file(const char *path, size_t *len)
{
	FILE *f = fopen(path, "rb");
	if (!f) die("cannot open %s: %s", path, strerror(errno));
	fseek(f, 0, SEEK_END);
	long n = ftell(f);
	fseek(f, 0, SEEK_SET);
	char *buf = malloc((size_t)n + 1);
	if (!buf) die("out of memory");
	if (n > 0 && fread(buf, 1, (size_t)n, f) != (size_t)n) die("cannot read %s", path);
	buf[n] = 0;
	fclose(f);
	*len = (size_t)n;
	return buf;
}

static void write_file(const char *path, const char *buf, size_t len)
{
	FILE *f = fopen(path, "wb");
	if (!f) die("cannot write %s: %s", path, strerror(errno));
	if (len > 0 && fwrite(buf, 1, len, f) != len) die("cannot write %s", path);
	if (fclose(f) != 0) die("cannot write %s", path);
}

/* Test suites are most of the tree by file count and are never compiled. */
static int skipped(const char *name)
{
	size_t n = strlen(name);
	return strcmp(name, "tests") == 0 || (n > 5 && strcmp(name + n - 5, ".phpt") == 0);
}

static void copy_tree(const char *src, const char *dst)
{
	DIR *d = opendir(src);
	if (!d) die("cannot open directory %s: %s", src, strerror(errno));
	make_dirs(dst);
	struct dirent *e;
	while ((e = readdir(d)) != NULL) {
		if (strcmp(e->d_name, ".") == 0 || strcmp(e->d_name, "..") == 0 || skipped(e->d_name)) continue;
		char *s = join(src, e->d_name), *t = join(dst, e->d_name);
		struct stat st;
		if (stat(s, &st) != 0) die("cannot stat %s: %s", s, strerror(errno));
		if (S_ISDIR(st.st_mode)) {
			copy_tree(s, t);
		} else if (S_ISREG(st.st_mode)) {
			size_t len;
			char *buf = read_file(s, &len);
			write_file(t, buf, len);
			free(buf);
		}
		free(s);
		free(t);
	}
	closedir(d);
}

/* A release archive holds one top-level directory. Zig normally unpacks a
 * package without it; where it is still there, step into it. */
static char *single_subdirectory(const char *dir)
{
	DIR *d = opendir(dir);
	if (!d) die("cannot open directory %s: %s", dir, strerror(errno));
	char *only = NULL;
	int entries = 0;
	struct dirent *e;
	while ((e = readdir(d)) != NULL) {
		if (strcmp(e->d_name, ".") == 0 || strcmp(e->d_name, "..") == 0) continue;
		if (++entries > 1) break;
		only = join(dir, e->d_name);
	}
	closedir(d);
	struct stat st;
	if (entries != 1 || stat(only, &st) != 0 || !S_ISDIR(st.st_mode)) return NULL;
	return only;
}

/* --- strict unified diff --------------------------------------------- */

typedef struct { char **v; size_t n, cap; } lines;

static void push(lines *l, char *s)
{
	if (l->n == l->cap) {
		l->cap = l->cap ? l->cap * 2 : 256;
		l->v = realloc(l->v, l->cap * sizeof *l->v);
		if (!l->v) die("out of memory");
	}
	l->v[l->n++] = s;
}

/* Split in place into lines without their terminating newline. */
static lines split(char *buf, int *ends_with_newline)
{
	lines l = {0};
	char *p = buf;
	*ends_with_newline = 1;
	while (*p) {
		char *nl = strchr(p, '\n');
		push(&l, p);
		if (!nl) { *ends_with_newline = 0; break; }
		*nl = 0;
		p = nl + 1;
	}
	return l;
}

static void apply_file(const char *out_dir, const char *rel, lines *pl, size_t from, size_t to, const char *patch)
{
	char *path = join(out_dir, rel);
	size_t len;
	char *buf = read_file(path, &len);
	int nl;
	lines old = split(buf, &nl), res = {0};
	size_t pos = 0; /* next unconsumed line of the original, 0-based */

	for (size_t i = from; i < to;) {
		long start, count = 1;
		const char *h = pl->v[i];
		if (strncmp(h, "@@ -", 4) != 0) die("%s: expected a hunk header, found: %s", patch, h);
		char *end;
		start = strtol(h + 4, &end, 10);
		if (*end == ',') count = strtol(end + 1, &end, 10);
		if (start < 1 && count != 0) die("%s: bad hunk header: %s", patch, h);
		size_t at = count == 0 ? (size_t)start : (size_t)start - 1;
		if (at < pos || at > old.n) die("%s: hunk out of order or out of range in %s: %s", patch, rel, h);
		while (pos < at) push(&res, old.v[pos++]);
		for (i++; i < to && strncmp(pl->v[i], "@@ -", 4) != 0; i++) {
			const char *l = pl->v[i];
			if (l[0] == '\\') continue; /* "\ No newline at end of file" */
			if (l[0] == '+') { push(&res, (char *)l + 1); continue; }
			if (l[0] != ' ' && l[0] != '-' && l[0] != 0) die("%s: unexpected line in hunk for %s: %s", patch, rel, l);
			const char *want = l[0] ? l + 1 : l;
			if (pos >= old.n || strcmp(old.v[pos], want) != 0)
				die("%s does not apply to %s at line %lu:\n  expected: %s\n  found:    %s",
					patch, rel, (unsigned long)pos + 1, want, pos < old.n ? old.v[pos] : "(end of file)");
			if (l[0] != '-') push(&res, old.v[pos]);
			pos++;
		}
	}
	while (pos < old.n) push(&res, old.v[pos++]);

	FILE *f = fopen(path, "wb");
	if (!f) die("cannot write %s: %s", path, strerror(errno));
	for (size_t i = 0; i < res.n; i++) {
		fputs(res.v[i], f);
		if (i + 1 < res.n || nl) fputc('\n', f);
	}
	if (fclose(f) != 0) die("cannot write %s", path);
	free(res.v);
	free(old.v);
	free(buf);
	free(path);
}

static void apply_patch(const char *out_dir, const char *patch)
{
	size_t len;
	char *buf = read_file(patch, &len);
	int nl;
	lines pl = split(buf, &nl);
	size_t files = 0;
	for (size_t i = 0; i < pl.n;) {
		if (strncmp(pl.v[i], "--- ", 4) != 0) { i++; continue; }
		if (i + 1 >= pl.n || strncmp(pl.v[i + 1], "+++ b/", 6) != 0) die("%s: '---' without '+++ b/PATH'", patch);
		char *rel = pl.v[i + 1] + 6;
		rel[strcspn(rel, "\t\r")] = 0;
		size_t from = i + 2, to = from;
		while (to < pl.n && strncmp(pl.v[to], "--- ", 4) != 0) to++;
		apply_file(out_dir, rel, &pl, from, to, patch);
		files++;
		i = to;
	}
	if (files == 0) die("%s: no files in patch", patch);
	free(pl.v);
	free(buf);
}

int main(int argc, char **argv)
{
	if (argc < 3) die("usage: prepare_src SRC_DIR OUT_DIR [PATCH_FILE...]");
	char *inner = single_subdirectory(argv[1]);
	copy_tree(inner ? inner : argv[1], argv[2]);
	for (int i = 3; i < argc; i++) apply_patch(argv[2], argv[i]);
	return 0;
}
