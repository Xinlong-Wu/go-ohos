// Copyright 2020 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package p

type T [10]*int

// Test for gcprog case, it's Type.PtrBytes should be large than 128*1024
// see src/cmd/compile/internal/reflectdata/reflectdata.dgcsym
type BT [128*1024/8+8]*int
