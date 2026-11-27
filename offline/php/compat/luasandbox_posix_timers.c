/* See luasandbox_posix_timers.h. */
#include <windows.h>
#include <errno.h>
#include <stdlib.h>
#include "luasandbox_posix_timers.h"

/* This file needs the real clock_gettime(). */
#undef clock_gettime

/* Times are in 100 ns units, as GetThreadTimes() reports them. */
typedef unsigned long long ticks;

struct luasandbox_win32_timer {
	HANDLE target;   /* the thread whose CPU time is measured */
	HANDLE wake;     /* set when the timer is armed, disarmed or deleted */
	CRITICAL_SECTION lock;
	void (*notify)(union sigval);
	union sigval value;
	ticks expiry;    /* CPU time of the target at which to notify */
	ticks interval;  /* 0 for a one-shot timer */
	int armed;
	int quit;
};

static ticks from_timespec(const struct timespec *ts)
{
	return (ticks)ts->tv_sec * 10000000ULL + (ticks)ts->tv_nsec / 100;
}

static void to_timespec(ticks t, struct timespec *ts)
{
	ts->tv_sec = (time_t)(t / 10000000ULL);
	ts->tv_nsec = (long)(t % 10000000ULL) * 100;
}

static ticks cpu_time(HANDLE thread)
{
	FILETIME created, exited, kernel, user;
	if (!GetThreadTimes(thread, &created, &exited, &kernel, &user)) {
		return 0;
	}
	return (((ticks)kernel.dwHighDateTime << 32) | kernel.dwLowDateTime)
		+ (((ticks)user.dwHighDateTime << 32) | user.dwLowDateTime);
}

/* Thread CPU clocks: clock id FIRST_THREAD_CLOCK + n names the thread in
 * slot n. A thread's slot is made the first time it asks for its clock and
 * kept for the life of the process; PHP runs on one thread here, so this is
 * one handle. */
#define FIRST_THREAD_CLOCK 1000
#define MAX_THREAD_CLOCKS 64
static struct { DWORD id; HANDLE handle; } thread_clocks[MAX_THREAD_CLOCKS];
static LONG thread_clock_count;
static SRWLOCK thread_clocks_lock = SRWLOCK_INIT;

static HANDLE thread_of_clock(clockid_t clock_id)
{
	int n = (int)clock_id - FIRST_THREAD_CLOCK;
	HANDLE h = NULL;
	AcquireSRWLockShared(&thread_clocks_lock);
	if (n >= 0 && n < thread_clock_count) h = thread_clocks[n].handle;
	ReleaseSRWLockShared(&thread_clocks_lock);
	return h;
}

int luasandbox_win32_getcpuclockid(clockid_t *clock_id)
{
	DWORD id = GetCurrentThreadId();
	int result = EAGAIN;
	AcquireSRWLockExclusive(&thread_clocks_lock);
	int n;
	for (n = 0; n < thread_clock_count; n++) {
		if (thread_clocks[n].id == id) break;
	}
	if (n == thread_clock_count && n < MAX_THREAD_CLOCKS
		&& DuplicateHandle(GetCurrentProcess(), GetCurrentThread(), GetCurrentProcess(),
			&thread_clocks[n].handle, THREAD_QUERY_INFORMATION, FALSE, 0)) {
		thread_clocks[n].id = id;
		thread_clock_count++;
	}
	if (n < thread_clock_count) {
		*clock_id = (clockid_t)(FIRST_THREAD_CLOCK + n);
		result = 0;
	}
	ReleaseSRWLockExclusive(&thread_clocks_lock);
	return result;
}

int luasandbox_win32_clock_gettime(clockid_t clock_id, struct timespec *ts)
{
	HANDLE thread = clock_id == CLOCK_THREAD_CPUTIME_ID ? GetCurrentThread() : thread_of_clock(clock_id);
	if (!thread) return clock_gettime(clock_id, ts);
	to_timespec(cpu_time(thread), ts);
	return 0;
}

static void destroy(timer_t t)
{
	CloseHandle(t->wake);
	DeleteCriticalSection(&t->lock);
	free(t);
}

static DWORD WINAPI watch(void *arg)
{
	timer_t t = arg;
	for (;;) {
		DWORD wait = INFINITE;
		void (*notify)(union sigval) = NULL;
		union sigval value;

		EnterCriticalSection(&t->lock);
		if (t->quit) {
			LeaveCriticalSection(&t->lock);
			destroy(t);
			return 0;
		}
		if (t->armed) {
			ticks now = cpu_time(t->target);
			if (now >= t->expiry) {
				notify = t->notify;
				value = t->value;
				if (t->interval) {
					t->expiry = now + t->interval;
				} else {
					t->armed = 0;
				}
			} else {
				/* The target cannot use CPU time faster than the clock runs,
				 * so it cannot reach the limit sooner than this. If it is idle
				 * it takes longer, and the loop comes round again. */
				ticks remaining = t->expiry - now;
				wait = (DWORD)(remaining / 10000);
				if (wait < 1) wait = 1;
			}
		}
		LeaveCriticalSection(&t->lock);

		if (notify) {
			notify(value);
		} else {
			WaitForSingleObject(t->wake, wait);
		}
	}
}

int timer_create(clockid_t clock_id, struct sigevent *event, timer_t *timer)
{
	HANDLE target = thread_of_clock(clock_id);
	if (!target || !event || event->sigev_notify != SIGEV_THREAD || !event->sigev_notify_function) {
		errno = EINVAL;
		return -1;
	}
	timer_t t = calloc(1, sizeof *t);
	if (!t) {
		errno = EAGAIN;
		return -1;
	}
	t->target = target; /* owned by the clock table, not by the timer */
	t->notify = event->sigev_notify_function;
	t->value = event->sigev_value;
	InitializeCriticalSection(&t->lock);
	t->wake = CreateEvent(NULL, FALSE, FALSE, NULL);
	HANDLE worker = t->wake ? CreateThread(NULL, 0, watch, t, 0, NULL) : NULL;
	if (!worker) {
		if (t->wake) CloseHandle(t->wake);
		DeleteCriticalSection(&t->lock);
		free(t);
		errno = EAGAIN;
		return -1;
	}
	/* The watcher runs detached and frees the timer itself, as below. */
	CloseHandle(worker);
	*timer = t;
	return 0;
}

static void remaining_locked(timer_t t, struct itimerspec *value)
{
	ticks now = cpu_time(t->target);
	to_timespec(t->armed && t->expiry > now ? t->expiry - now : 0, &value->it_value);
	to_timespec(t->interval, &value->it_interval);
}

int timer_settime(timer_t t, int flags, const struct itimerspec *value, struct itimerspec *old_value)
{
	(void)flags; /* LuaSandbox only sets relative times */
	if (!t || !value) {
		errno = EINVAL;
		return -1;
	}
	EnterCriticalSection(&t->lock);
	if (old_value) remaining_locked(t, old_value);
	ticks after = from_timespec(&value->it_value);
	t->interval = from_timespec(&value->it_interval);
	t->armed = after != 0;
	t->expiry = cpu_time(t->target) + after;
	LeaveCriticalSection(&t->lock);
	SetEvent(t->wake);
	return 0;
}

int timer_gettime(timer_t t, struct itimerspec *value)
{
	if (!t || !value) {
		errno = EINVAL;
		return -1;
	}
	EnterCriticalSection(&t->lock);
	remaining_locked(t, value);
	LeaveCriticalSection(&t->lock);
	return 0;
}

/* Does not wait for the watcher: as with POSIX timers, a notification that
 * is already running may finish after this returns. LuaSandbox deletes a
 * timer while holding the semaphore its notification waits for, so waiting
 * here could deadlock. The watcher frees the timer when it next looks. */
int timer_delete(timer_t t)
{
	if (!t) {
		errno = EINVAL;
		return -1;
	}
	EnterCriticalSection(&t->lock);
	t->quit = 1;
	t->armed = 0;
	LeaveCriticalSection(&t->lock);
	SetEvent(t->wake);
	return 0;
}

int timer_getoverrun(timer_t t)
{
	(void)t;
	return 0;
}
