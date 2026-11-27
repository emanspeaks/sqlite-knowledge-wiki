/* POSIX per-thread CPU-time timers for LuaSandbox on Windows.
 *
 * LuaSandbox enforces a script's CPU-time limit with timer_create() on the
 * running thread's CPU clock and a notification on another thread. Windows
 * has no such call, and MinGW-w64's pthreads library (which supplies the
 * locks, semaphores and clocks LuaSandbox also uses) does not provide it.
 * These are the functions LuaSandbox calls, implemented on Win32 in
 * luasandbox_posix_timers.c. Only what LuaSandbox uses is supported:
 * SIGEV_THREAD notification, on the CPU time of the thread that created
 * the timer.
 */
#ifndef LUASANDBOX_POSIX_TIMERS_H
#define LUASANDBOX_POSIX_TIMERS_H

#include <time.h>
#include <pthread_time.h>

typedef struct luasandbox_win32_timer *timer_t;

union sigval {
	int sival_int;
	void *sival_ptr;
};

struct sigevent {
	int sigev_notify;
	int sigev_signo;
	union sigval sigev_value;
	void (*sigev_notify_function)(union sigval);
	void *sigev_notify_attributes;
};

#define SIGEV_THREAD 2

/* struct itimerspec and clockid_t come from MinGW-w64's pthread_time.h. */
int timer_create(clockid_t clock_id, struct sigevent *event, timer_t *timer);
int timer_settime(timer_t timer, int flags, const struct itimerspec *value, struct itimerspec *old_value);
int timer_gettime(timer_t timer, struct itimerspec *value);
int timer_delete(timer_t timer);
/* Always 0: missed periods of a repeating timer are not counted. LuaSandbox's
 * profiler uses the count; its samples are slightly under-weighted without it. */
int timer_getoverrun(timer_t timer);

#endif
