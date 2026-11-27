/* See luasandbox_posix_timers.h. */
#include <windows.h>
#include <errno.h>
#include <stdlib.h>
#include "luasandbox_posix_timers.h"

/* Times are in 100 ns units, as GetThreadTimes() reports them. */
typedef unsigned long long ticks;

struct luasandbox_win32_timer {
	HANDLE target;   /* the thread whose CPU time is measured */
	HANDLE worker;   /* the thread that watches it and delivers the notification */
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
	(void)clock_id;
	if (!event || event->sigev_notify != SIGEV_THREAD || !event->sigev_notify_function) {
		errno = EINVAL;
		return -1;
	}
	timer_t t = calloc(1, sizeof *t);
	if (!t) {
		errno = EAGAIN;
		return -1;
	}
	t->notify = event->sigev_notify_function;
	t->value = event->sigev_value;
	InitializeCriticalSection(&t->lock);
	t->wake = CreateEvent(NULL, FALSE, FALSE, NULL);
	if (t->wake && DuplicateHandle(GetCurrentProcess(), GetCurrentThread(), GetCurrentProcess(),
			&t->target, THREAD_QUERY_INFORMATION, FALSE, 0)) {
		t->worker = CreateThread(NULL, 0, watch, t, 0, NULL);
	}
	if (!t->worker) {
		if (t->target) CloseHandle(t->target);
		if (t->wake) CloseHandle(t->wake);
		DeleteCriticalSection(&t->lock);
		free(t);
		errno = EAGAIN;
		return -1;
	}
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

int timer_delete(timer_t t)
{
	if (!t) {
		errno = EINVAL;
		return -1;
	}
	EnterCriticalSection(&t->lock);
	t->quit = 1;
	LeaveCriticalSection(&t->lock);
	SetEvent(t->wake);
	WaitForSingleObject(t->worker, INFINITE);
	CloseHandle(t->worker);
	CloseHandle(t->target);
	CloseHandle(t->wake);
	DeleteCriticalSection(&t->lock);
	free(t);
	return 0;
}

int timer_getoverrun(timer_t t)
{
	(void)t;
	return 0;
}
