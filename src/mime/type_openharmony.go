// Copyright 2024 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package mime

func init() {
	typeFiles = append(typeFiles, "/system/etc/cups/share/mime/mime.types")
}
