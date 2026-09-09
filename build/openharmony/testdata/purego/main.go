package main

import (
	"crypto/rand"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"os/signal"
	"runtime"
	"runtime/debug"
	"sync"
	"sync/atomic"
	"syscall"
	"time"
)

func fail(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "openharmony pure-go smoke: FAIL: "+format+"\n", args...)
	os.Exit(1)
}

func check(err error, format string, args ...any) {
	if err != nil {
		fail(format+": %v", append(args, err)...)
	}
}

func main() {
	if len(os.Args) > 1 && os.Args[1] == "--child" {
		fmt.Println("child-ok")
		return
	}
	if len(os.Args) > 1 && os.Args[1] == "--intentional-failure" {
		os.Exit(97)
	}

	if !runtime.IsOpenharmony {
		fail("runtime.IsOpenharmony is false (GOOS=%s GOARCH=%s)", runtime.GOOS, runtime.GOARCH)
	}
	if runtime.GOARCH != "arm64" {
		fail("unexpected architecture: %s", runtime.GOARCH)
	}
	if version := runtime.Version(); len(version) < 3 || version[:2] != "go" {
		fail("unexpected Go version: %q", version)
	} else if expected := os.Getenv("OPENHARMONY_EXPECTED_GO_VERSION"); expected != "" && version != expected {
		fail("Go version is %q, expected %q", version, expected)
	}

	var counter atomic.Int64
	var wg sync.WaitGroup
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < 1000; j++ {
				counter.Add(1)
			}
		}()
	}
	wg.Wait()
	if got := counter.Load(); got != 8000 {
		fail("atomic/goroutine result is %d, want 8000", got)
	}

	debug.SetGCPercent(100)
	buf := make([]byte, 8<<20)
	for i := range buf {
		buf[i] = byte(i)
	}
	runtime.KeepAlive(buf)
	runtime.GC()

	timer := time.NewTimer(10 * time.Millisecond)
	select {
	case <-timer.C:
	case <-time.After(2 * time.Second):
		fail("timer did not fire")
	}

	tmp, err := os.MkdirTemp("", "go-ohos-smoke-")
	check(err, "create temporary directory")
	defer os.RemoveAll(tmp)
	first := tmp + "/first.txt"
	second := tmp + "/second.txt"
	check(os.WriteFile(first, []byte("openharmony\n"), 0600), "write temporary file")
	check(os.Chmod(first, 0600), "chmod temporary file")
	check(os.Rename(first, second), "rename temporary file")
	contents, err := os.ReadFile(second)
	check(err, "read temporary file")
	if string(contents) != "openharmony\n" {
		fail("temporary file contents are %q", contents)
	}

	signalCh := make(chan os.Signal, 1)
	signal.Notify(signalCh, syscall.SIGUSR1)
	check(syscall.Kill(syscall.Getpid(), syscall.SIGUSR1), "send SIGUSR1")
	select {
	case got := <-signalCh:
		if got != syscall.SIGUSR1 {
			fail("received signal %v, want SIGUSR1", got)
		}
	case <-time.After(2 * time.Second):
		fail("did not receive SIGUSR1")
	}
	signal.Stop(signalCh)

	listener, err := net.Listen("tcp4", "127.0.0.1:0")
	check(err, "listen on loopback")
	serverDone := make(chan error, 1)
	go func() {
		conn, acceptErr := listener.Accept()
		if acceptErr != nil {
			serverDone <- acceptErr
			return
		}
		defer conn.Close()
		data := make([]byte, len("ping"))
		_, readErr := io.ReadFull(conn, data)
		if readErr == nil && string(data) != "ping" {
			readErr = fmt.Errorf("received %q", data)
		}
		if readErr == nil {
			_, readErr = conn.Write([]byte("pong"))
		}
		serverDone <- readErr
	}()
	conn, err := net.Dial("tcp4", listener.Addr().String())
	check(err, "connect to loopback")
	_, err = conn.Write([]byte("ping"))
	check(err, "write loopback request")
	response, err := io.ReadAll(io.LimitReader(conn, 4))
	check(err, "read loopback response")
	check(conn.Close(), "close loopback connection")
	check(listener.Close(), "close loopback listener")
	check(<-serverDone, "loopback server")
	if string(response) != "pong" {
		fail("loopback response is %q", response)
	}

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.WriteString(w, "http-ok")
	}))
	responseHTTP, err := server.Client().Get(server.URL)
	check(err, "HTTP loopback request")
	body, err := io.ReadAll(responseHTTP.Body)
	check(err, "read HTTP response")
	check(responseHTTP.Body.Close(), "close HTTP response")
	server.Close()
	if string(body) != "http-ok" {
		fail("HTTP response is %q", body)
	}

	tlsServer := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.WriteString(w, "tls-ok")
	}))
	tlsResponse, err := tlsServer.Client().Get(tlsServer.URL)
	check(err, "HTTPS loopback request")
	tlsBody, err := io.ReadAll(tlsResponse.Body)
	check(err, "read HTTPS response")
	check(tlsResponse.Body.Close(), "close HTTPS response")
	tlsServer.Close()
	if string(tlsBody) != "tls-ok" {
		fail("HTTPS response is %q", tlsBody)
	}

	randomBytes := make([]byte, 32)
	_, err = rand.Read(randomBytes)
	check(err, "read crypto/rand")

	child := exec.Command(os.Args[0], "--child")
	childOutput, err := child.CombinedOutput()
	check(err, "run subprocess (output %q)", childOutput)
	if string(childOutput) != "child-ok\n" {
		fail("subprocess output is %q", childOutput)
	}

	fmt.Printf("openharmony pure-go smoke: PASS (GOOS=%s IsOpenharmony=%t GOARCH=%s version=%s)\n", runtime.GOOS, runtime.IsOpenharmony, runtime.GOARCH, runtime.Version())
}
