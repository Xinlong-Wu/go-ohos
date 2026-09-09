#include <errno.h>
#include <pthread.h>

static __thread int tls_value;

int ohos_add(int a, int b) {
	return a + b;
}

int ohos_errno_probe(void) {
	errno = ENOENT;
	return errno;
}

int ohos_tls_roundtrip(void) {
	tls_value = 0x4f53;
	return tls_value;
}

extern void go_callback(int);

static void *callback_thread(void *unused) {
	(void)unused;
	go_callback(0x27);
	return 0;
}

int ohos_start_callback(void) {
	pthread_t thread;
	if (pthread_create(&thread, 0, callback_thread, 0) != 0) {
		return -1;
	}
	return pthread_join(thread, 0);
}
