// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "go_asm.h"
#include "go_tls.h"
#include "funcdata.h"
#include "textflag.h"
#include "tls_arm64.h"

TEXT runtime·load_g(SB),NOSPLIT,$0
#ifndef GOOS_darwin
#ifndef GOOS_openbsd
#ifndef GOOS_windows
	MOVB	runtime·iscgo(SB), R0
	CBZ	R0, nocgo
#endif
#endif
#endif

	MRS_TPIDR_R0
#ifdef GOOS_darwin
	// Darwin (macOS) 逻辑：必须保持原样
	AND $0xfffffffffffffff8, R0
	MOVD	runtime·tls_g(SB), R27
	MOVD	(R0)(R27), g
#else
    // Musl/Linux TLS GD 逻辑
    MOVD R0, R27
	MOVD runtime·tls_g(SB), R1
	CALL (R1)
	MOVD (R27)(R0), g
#endif

nocgo:
    RET

TEXT runtime·save_g(SB),NOSPLIT,$0
#ifndef GOOS_darwin
#ifndef GOOS_openbsd
#ifndef GOOS_windows
	MOVB	runtime·iscgo(SB), R0
	CBZ	R0, nocgo
#endif
#endif
#endif

    MRS_TPIDR_R0
#ifdef GOOS_darwin
    // Darwin (macOS) 逻辑：防止 blr x1 跳转到 0x810
    AND	$0xfffffffffffffff8, R0
	MOVD	runtime·tls_g(SB), R27
	MOVD	g, (R0)(R27)
#else
	// Musl/Linux TLS GD 逻辑
	MOVD	R0, R27 
    MOVD	runtime·tls_g(SB), R1
	CALL	(R1)
    MOVD	g, (R27)(R0)
#endif

nocgo:
    RET

#ifdef TLSG_IS_VARIABLE
#ifdef GOOS_android
// Use the free TLS_SLOT_APP slot #2 on Android Q.
// Earlier androids are set up in gcc_android.c.
DATA runtime·tls_g+0(SB)/8, $16
#endif
GLOBL runtime·tls_g+0(SB), NOPTR, $8
#else
GLOBL runtime·tls_g+0(SB), TLSBSS, $8
#endif
