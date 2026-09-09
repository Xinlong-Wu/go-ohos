package main

/*
#cgo CFLAGS: -pthread
#cgo LDFLAGS: -pthread
#include <stdint.h>

int ohos_add(int, int);
int ohos_errno_probe(void);
int ohos_tls_roundtrip(void);
int ohos_start_callback(void);
extern void go_callback(int);
*/
import "C"

import (
	"fmt"
	"os"
	"runtime"
	"time"
)

var callbackResult = make(chan int, 1)

//export go_callback
func go_callback(value C.int) {
	callbackResult <- int(value)
}

func fail(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "openharmony cgo smoke: FAIL: "+format+"\n", args...)
	os.Exit(1)
}

func main() {
	if !runtime.IsOpenharmony || runtime.GOARCH != "arm64" {
		fail("unexpected target: GOOS=%s IsOpenharmony=%t GOARCH=%s", runtime.GOOS, runtime.IsOpenharmony, runtime.GOARCH)
	}
	if got := int(C.ohos_add(2, 40)); got != 42 {
		fail("C addition returned %d, want 42", got)
	}
	if got := int(C.ohos_errno_probe()); got == 0 {
		fail("C errno probe returned zero")
	}
	if got := int(C.ohos_tls_roundtrip()); got != 0x4f53 {
		fail("C TLS roundtrip returned %#x, want %#x", got, 0x4f53)
	}
	if got := int(C.ohos_start_callback()); got != 0 {
		fail("pthread callback setup returned %d", got)
	}
	select {
	case got := <-callbackResult:
		if got != 0x27 {
			fail("C pthread callback returned %d, want %d", got, 0x27)
		}
	case <-time.After(3 * time.Second):
		fail("timed out waiting for C pthread callback")
	}

	fmt.Printf("openharmony cgo smoke: PASS (GOOS=%s IsOpenharmony=%t GOARCH=%s version=%s)\n", runtime.GOOS, runtime.IsOpenharmony, runtime.GOARCH, runtime.Version())
}
