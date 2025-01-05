// Copyright 2024 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package runtime_test

import (
	. "runtime"
	"testing"
)

func TestHeapAddrBitsValue(t *testing.T) {
	if GOARCH == "arm64" && IsOpenharmony {
		if HeapAddrBits != 39 {
			t.Fatalf("heapAddrBits = %d, want 39", HeapAddrBits)
		}
	} else if (GOARCH == "amd64" || GOARCH == "arm64") && GOOS == "linux" {
		if HeapAddrBits != 48 {
			t.Fatalf("heapAddrBits = %d, want 48", HeapAddrBits)
		}
	} else {
		t.Skip()
	}
}
