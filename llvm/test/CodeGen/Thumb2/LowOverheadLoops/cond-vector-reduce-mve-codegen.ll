; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc -mtriple=thumbv8.1m.main -mattr=+mve -disable-mve-tail-predication=false --verify-machineinstrs %s -o - | FileCheck %s

define dso_local i32 @vpsel_mul_reduce_add(i32* noalias nocapture readonly %a, i32* noalias nocapture readonly %b, i32* noalias nocapture readonly %c, i32 %N) {
; CHECK-LABEL: vpsel_mul_reduce_add:
; CHECK:       @ %bb.0: @ %entry
; CHECK-NEXT:    cmp r3, #0
; CHECK-NEXT:    itt eq
; CHECK-NEXT:    moveq r0, #0
; CHECK-NEXT:    bxeq lr
; CHECK-NEXT:    push {r4, r5, r7, lr}
; CHECK-NEXT:    sub sp, #4
; CHECK-NEXT:    adds r4, r3, #3
; CHECK-NEXT:    vmov.i32 q1, #0x0
; CHECK-NEXT:    bic r4, r4, #3
; CHECK-NEXT:    sub.w r12, r4, #4
; CHECK-NEXT:    movs r4, #1
; CHECK-NEXT:    add.w lr, r4, r12, lsr #2
; CHECK-NEXT:    lsr.w r4, r12, #2
; CHECK-NEXT:    sub.w r12, r3, r4, lsl #2
; CHECK-NEXT:    movs r4, #0
; CHECK-NEXT:    dls lr, lr
; CHECK-NEXT:  .LBB0_1: @ %vector.body
; CHECK-NEXT:    @ =>This Inner Loop Header: Depth=1
; CHECK-NEXT:    vctp.32 r3
; CHECK-NEXT:    and r5, r4, #15
; CHECK-NEXT:    vstr p0, [sp] @ 4-byte Spill
; CHECK-NEXT:    vdup.32 q3, r5
; CHECK-NEXT:    vmov q0, q1
; CHECK-NEXT:    vpstt
; CHECK-NEXT:    vldrwt.u32 q1, [r2], #16
; CHECK-NEXT:    vldrwt.u32 q2, [r1], #16
; CHECK-NEXT:    vcmp.i32 eq, q3, zr
; CHECK-NEXT:    adds r4, #4
; CHECK-NEXT:    vpsel q1, q2, q1
; CHECK-NEXT:    vldr p0, [sp] @ 4-byte Reload
; CHECK-NEXT:    vpst
; CHECK-NEXT:    vldrwt.u32 q2, [r0], #16
; CHECK-NEXT:    vmul.i32 q1, q1, q2
; CHECK-NEXT:    subs r3, #4
; CHECK-NEXT:    vadd.i32 q1, q1, q0
; CHECK-NEXT:    le lr, .LBB0_1
; CHECK-NEXT:  @ %bb.2: @ %middle.block
; CHECK-NEXT:    vctp.32 r12
; CHECK-NEXT:    vpsel q0, q1, q0
; CHECK-NEXT:    vaddv.u32 r0, q0
; CHECK-NEXT:    add sp, #4
; CHECK-NEXT:    pop {r4, r5, r7, pc}
entry:
  %cmp8 = icmp eq i32 %N, 0
  br i1 %cmp8, label %for.cond.cleanup, label %vector.ph

vector.ph:                                        ; preds = %entry
  %n.rnd.up = add i32 %N, 3
  %n.vec = and i32 %n.rnd.up, -4
  %trip.count.minus.1 = add i32 %N, -1
  %broadcast.splatinsert11 = insertelement <4 x i32> undef, i32 %trip.count.minus.1, i32 0
  %broadcast.splat12 = shufflevector <4 x i32> %broadcast.splatinsert11, <4 x i32> undef, <4 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i32 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %vec.phi = phi <4 x i32> [ zeroinitializer, %vector.ph ], [ %add, %vector.body ]
  %broadcast.splatinsert = insertelement <4 x i32> undef, i32 %index, i32 0
  %broadcast.splat = shufflevector <4 x i32> %broadcast.splatinsert, <4 x i32> undef, <4 x i32> zeroinitializer
  %induction = add <4 x i32> %broadcast.splat, <i32 0, i32 1, i32 2, i32 3>
  %tmp = getelementptr inbounds i32, i32* %a, i32 %index
  %tmp1 = icmp ule <4 x i32> %induction, %broadcast.splat12
  %tmp2 = bitcast i32* %tmp to <4 x i32>*
  %wide.masked.load.a = call <4 x i32> @llvm.masked.load.v4i32.p0v4i32(<4 x i32>* %tmp2, i32 4, <4 x i1> %tmp1, <4 x i32> undef)
  %tmp3 = getelementptr inbounds i32, i32* %b, i32 %index
  %tmp4 = bitcast i32* %tmp3 to <4 x i32>*
  %wide.masked.load.b = call <4 x i32> @llvm.masked.load.v4i32.p0v4i32(<4 x i32>* %tmp4, i32 4, <4 x i1> %tmp1, <4 x i32> undef)
  %tmp5 = getelementptr inbounds i32, i32* %c, i32 %index
  %tmp6 = bitcast i32* %tmp5 to <4 x i32>*
  %wide.masked.load.c = call <4 x i32> @llvm.masked.load.v4i32.p0v4i32(<4 x i32>* %tmp6, i32 4, <4 x i1> %tmp1, <4 x i32> undef)
  %rem = urem i32 %index, 16
  %rem.broadcast.splatinsert = insertelement <4 x i32> undef, i32 %rem, i32 0
  %rem.broadcast.splat = shufflevector <4 x i32> %rem.broadcast.splatinsert, <4 x i32> undef, <4 x i32> zeroinitializer
  %cmp = icmp eq <4 x i32> %rem.broadcast.splat, <i32 0, i32 0, i32 0, i32 0>
  %wide.masked.load = select <4 x i1> %cmp, <4 x i32> %wide.masked.load.b, <4 x i32> %wide.masked.load.c
  %mul = mul nsw <4 x i32> %wide.masked.load, %wide.masked.load.a
  %add = add nsw <4 x i32> %mul, %vec.phi
  %index.next = add i32 %index, 4
  %tmp7 = icmp eq i32 %index.next, %n.vec
  br i1 %tmp7, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %tmp8 = select <4 x i1> %tmp1, <4 x i32> %add, <4 x i32> %vec.phi
  %tmp9 = call i32 @llvm.experimental.vector.reduce.add.v4i32(<4 x i32> %tmp8)
  br label %for.cond.cleanup

for.cond.cleanup:                                 ; preds = %middle.block, %entry
  %res.0.lcssa = phi i32 [ 0, %entry ], [ %tmp9, %middle.block ]
  ret i32 %res.0.lcssa
}

define dso_local i32 @vpsel_mul_reduce_add_2(i32* noalias nocapture readonly %a, i32* noalias nocapture readonly %b,
; CHECK-LABEL: vpsel_mul_reduce_add_2:
; CHECK:       @ %bb.0: @ %entry
; CHECK-NEXT:    push {r4, r5, r6, lr}
; CHECK-NEXT:    sub sp, #4
; CHECK-NEXT:    ldr.w r12, [sp, #20]
; CHECK-NEXT:    cmp.w r12, #0
; CHECK-NEXT:    beq .LBB1_4
; CHECK-NEXT:  @ %bb.1: @ %vector.ph
; CHECK-NEXT:    add.w r5, r12, #3
; CHECK-NEXT:    vmov.i32 q1, #0x0
; CHECK-NEXT:    bic r5, r5, #3
; CHECK-NEXT:    subs r4, r5, #4
; CHECK-NEXT:    movs r5, #1
; CHECK-NEXT:    add.w lr, r5, r4, lsr #2
; CHECK-NEXT:    lsrs r4, r4, #2
; CHECK-NEXT:    sub.w r4, r12, r4, lsl #2
; CHECK-NEXT:    movs r5, #0
; CHECK-NEXT:    dls lr, lr
; CHECK-NEXT:  .LBB1_2: @ %vector.body
; CHECK-NEXT:    @ =>This Inner Loop Header: Depth=1
; CHECK-NEXT:    vctp.32 r12
; CHECK-NEXT:    and r6, r5, #15
; CHECK-NEXT:    vstr p0, [sp] @ 4-byte Spill
; CHECK-NEXT:    vmov q0, q1
; CHECK-NEXT:    vpstt
; CHECK-NEXT:    vldrwt.u32 q1, [r3], #16
; CHECK-NEXT:    vldrwt.u32 q2, [r2], #16
; CHECK-NEXT:    vdup.32 q3, r6
; CHECK-NEXT:    vsub.i32 q1, q2, q1
; CHECK-NEXT:    vpst
; CHECK-NEXT:    vldrwt.u32 q2, [r1], #16
; CHECK-NEXT:    vcmp.i32 eq, q3, zr
; CHECK-NEXT:    adds r5, #4
; CHECK-NEXT:    vpsel q1, q1, q2
; CHECK-NEXT:    vldr p0, [sp] @ 4-byte Reload
; CHECK-NEXT:    vpst
; CHECK-NEXT:    vldrwt.u32 q2, [r0], #16
; CHECK-NEXT:    vmul.i32 q1, q1, q2
; CHECK-NEXT:    sub.w r12, r12, #4
; CHECK-NEXT:    vadd.i32 q1, q1, q0
; CHECK-NEXT:    le lr, .LBB1_2
; CHECK-NEXT:  @ %bb.3: @ %middle.block
; CHECK-NEXT:    vctp.32 r4
; CHECK-NEXT:    vpsel q0, q1, q0
; CHECK-NEXT:    vaddv.u32 r0, q0
; CHECK-NEXT:    add sp, #4
; CHECK-NEXT:    pop {r4, r5, r6, pc}
; CHECK-NEXT:  .LBB1_4:
; CHECK-NEXT:    movs r0, #0
; CHECK-NEXT:    add sp, #4
; CHECK-NEXT:    pop {r4, r5, r6, pc}
                                         i32* noalias nocapture readonly %c, i32* noalias nocapture readonly %d, i32 %N) {
entry:
  %cmp8 = icmp eq i32 %N, 0
  br i1 %cmp8, label %for.cond.cleanup, label %vector.ph

vector.ph:                                        ; preds = %entry
  %n.rnd.up = add i32 %N, 3
  %n.vec = and i32 %n.rnd.up, -4
  %trip.count.minus.1 = add i32 %N, -1
  %broadcast.splatinsert11 = insertelement <4 x i32> undef, i32 %trip.count.minus.1, i32 0
  %broadcast.splat12 = shufflevector <4 x i32> %broadcast.splatinsert11, <4 x i32> undef, <4 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i32 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %vec.phi = phi <4 x i32> [ zeroinitializer, %vector.ph ], [ %add, %vector.body ]
  %broadcast.splatinsert = insertelement <4 x i32> undef, i32 %index, i32 0
  %broadcast.splat = shufflevector <4 x i32> %broadcast.splatinsert, <4 x i32> undef, <4 x i32> zeroinitializer
  %induction = add <4 x i32> %broadcast.splat, <i32 0, i32 1, i32 2, i32 3>
  %tmp = getelementptr inbounds i32, i32* %a, i32 %index
  %tmp1 = icmp ule <4 x i32> %induction, %broadcast.splat12
  %tmp2 = bitcast i32* %tmp to <4 x i32>*
  %wide.masked.load.a = call <4 x i32> @llvm.masked.load.v4i32.p0v4i32(<4 x i32>* %tmp2, i32 4, <4 x i1> %tmp1, <4 x i32> undef)
  %tmp3 = getelementptr inbounds i32, i32* %b, i32 %index
  %tmp4 = bitcast i32* %tmp3 to <4 x i32>*
  %wide.masked.load.b = call <4 x i32> @llvm.masked.load.v4i32.p0v4i32(<4 x i32>* %tmp4, i32 4, <4 x i1> %tmp1, <4 x i32> undef)
  %tmp5 = getelementptr inbounds i32, i32* %c, i32 %index
  %tmp6 = bitcast i32* %tmp5 to <4 x i32>*
  %wide.masked.load.c = call <4 x i32> @llvm.masked.load.v4i32.p0v4i32(<4 x i32>* %tmp6, i32 4, <4 x i1> %tmp1, <4 x i32> undef)
  %tmp7 = getelementptr inbounds i32, i32* %d, i32 %index
  %tmp8 = bitcast i32* %tmp7 to <4 x i32>*
  %wide.masked.load.d = call <4 x i32> @llvm.masked.load.v4i32.p0v4i32(<4 x i32>* %tmp8, i32 4, <4 x i1> %tmp1, <4 x i32> undef)
  %sub = sub <4 x i32> %wide.masked.load.c, %wide.masked.load.d
  %rem = urem i32 %index, 16
  %rem.broadcast.splatinsert = insertelement <4 x i32> undef, i32 %rem, i32 0
  %rem.broadcast.splat = shufflevector <4 x i32> %rem.broadcast.splatinsert, <4 x i32> undef, <4 x i32> zeroinitializer
  %cmp = icmp eq <4 x i32> %rem.broadcast.splat, <i32 0, i32 0, i32 0, i32 0>
  %sel = select <4 x i1> %cmp, <4 x i32> %sub, <4 x i32> %wide.masked.load.b
  %mul = mul  <4 x i32> %sel, %wide.masked.load.a
  %add = add  <4 x i32> %mul, %vec.phi
  %index.next = add i32 %index, 4
  %cmp.exit = icmp eq i32 %index.next, %n.vec
  br i1 %cmp.exit, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %acc = select <4 x i1> %tmp1, <4 x i32> %add, <4 x i32> %vec.phi
  %reduce = call i32 @llvm.experimental.vector.reduce.add.v4i32(<4 x i32> %acc)
  br label %for.cond.cleanup

for.cond.cleanup:                                 ; preds = %middle.block, %entry
  %res.0.lcssa = phi i32 [ 0, %entry ], [ %reduce, %middle.block ]
  ret i32 %res.0.lcssa
}

define dso_local i32 @and_mul_reduce_add(i32* noalias nocapture readonly %a, i32* noalias nocapture readonly %b,
; CHECK-LABEL: and_mul_reduce_add:
; CHECK:       @ %bb.0: @ %entry
; CHECK-NEXT:    push {r4, r5, r7, lr}
; CHECK-NEXT:    ldr.w r12, [sp, #16]
; CHECK-NEXT:    cmp.w r12, #0
; CHECK-NEXT:    beq .LBB2_4
; CHECK-NEXT:  @ %bb.1: @ %vector.ph
; CHECK-NEXT:    add.w r4, r12, #3
; CHECK-NEXT:    vmov.i32 q1, #0x0
; CHECK-NEXT:    bic r4, r4, #3
; CHECK-NEXT:    subs r5, r4, #4
; CHECK-NEXT:    movs r4, #1
; CHECK-NEXT:    add.w lr, r4, r5, lsr #2
; CHECK-NEXT:    lsrs r4, r5, #2
; CHECK-NEXT:    sub.w r4, r12, r4, lsl #2
; CHECK-NEXT:    dls lr, lr
; CHECK-NEXT:  .LBB2_2: @ %vector.body
; CHECK-NEXT:    @ =>This Inner Loop Header: Depth=1
; CHECK-NEXT:    vctp.32 r12
; CHECK-NEXT:    vmov q0, q1
; CHECK-NEXT:    vpstt
; CHECK-NEXT:    vldrwt.u32 q1, [r1], #16
; CHECK-NEXT:    vldrwt.u32 q2, [r0], #16
; CHECK-NEXT:    sub.w r12, r12, #4
; CHECK-NEXT:    vsub.i32 q1, q2, q1
; CHECK-NEXT:    vpsttt
; CHECK-NEXT:    vcmpt.i32 eq, q1, zr
; CHECK-NEXT:    vldrwt.u32 q1, [r3], #16
; CHECK-NEXT:    vldrwt.u32 q2, [r2], #16
; CHECK-NEXT:    vmul.i32 q1, q2, q1
; CHECK-NEXT:    vadd.i32 q1, q1, q0
; CHECK-NEXT:    le lr, .LBB2_2
; CHECK-NEXT:  @ %bb.3: @ %middle.block
; CHECK-NEXT:    vctp.32 r4
; CHECK-NEXT:    vpsel q0, q1, q0
; CHECK-NEXT:    vaddv.u32 r0, q0
; CHECK-NEXT:    pop {r4, r5, r7, pc}
; CHECK-NEXT:  .LBB2_4:
; CHECK-NEXT:    movs r0, #0
; CHECK-NEXT:    pop {r4, r5, r7, pc}
                                         i32* noalias nocapture readonly %c, i32* noalias nocapture readonly %d, i32 %N) {
entry:
  %cmp8 = icmp eq i32 %N, 0
  br i1 %cmp8, label %for.cond.cleanup, label %vector.ph

vector.ph:                                        ; preds = %entry
  %n.rnd.up = add i32 %N, 3
  %n.vec = and i32 %n.rnd.up, -4
  %trip.count.minus.1 = add i32 %N, -1
  %broadcast.splatinsert11 = insertelement <4 x i32> undef, i32 %trip.count.minus.1, i32 0
  %broadcast.splat12 = shufflevector <4 x i32> %broadcast.splatinsert11, <4 x i32> undef, <4 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i32 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %vec.phi = phi <4 x i32> [ zeroinitializer, %vector.ph ], [ %add, %vector.body ]
  %broadcast.splatinsert = insertelement <4 x i32> undef, i32 %index, i32 0
  %broadcast.splat = shufflevector <4 x i32> %broadcast.splatinsert, <4 x i32> undef, <4 x i32> zeroinitializer
  %induction = add <4 x i32> %broadcast.splat, <i32 0, i32 1, i32 2, i32 3>
  %tmp = getelementptr inbounds i32, i32* %a, i32 %index
  %tmp1 = icmp ule <4 x i32> %induction, %broadcast.splat12
  %tmp2 = bitcast i32* %tmp to <4 x i32>*
  %wide.masked.load.a = call <4 x i32> @llvm.masked.load.v4i32.p0v4i32(<4 x i32>* %tmp2, i32 4, <4 x i1> %tmp1, <4 x i32> undef)
  %tmp3 = getelementptr inbounds i32, i32* %b, i32 %index
  %tmp4 = bitcast i32* %tmp3 to <4 x i32>*
  %wide.masked.load.b = call <4 x i32> @llvm.masked.load.v4i32.p0v4i32(<4 x i32>* %tmp4, i32 4, <4 x i1> %tmp1, <4 x i32> undef)
  %sub = sub <4 x i32> %wide.masked.load.a, %wide.masked.load.b
  %cmp = icmp eq <4 x i32> %sub, <i32 0, i32 0, i32 0, i32 0>
  %mask = and <4 x i1> %cmp, %tmp1
  %tmp5 = getelementptr inbounds i32, i32* %c, i32 %index
  %tmp6 = bitcast i32* %tmp5 to <4 x i32>*
  %wide.masked.load.c = call <4 x i32> @llvm.masked.load.v4i32.p0v4i32(<4 x i32>* %tmp6, i32 4, <4 x i1> %mask, <4 x i32> undef)
  %tmp7 = getelementptr inbounds i32, i32* %d, i32 %index
  %tmp8 = bitcast i32* %tmp7 to <4 x i32>*
  %wide.masked.load.d = call <4 x i32> @llvm.masked.load.v4i32.p0v4i32(<4 x i32>* %tmp8, i32 4, <4 x i1> %mask, <4 x i32> undef)
  %mul = mul  <4 x i32> %wide.masked.load.c, %wide.masked.load.d
  %add = add  <4 x i32> %mul, %vec.phi
  %index.next = add i32 %index, 4
  %cmp.exit = icmp eq i32 %index.next, %n.vec
  br i1 %cmp.exit, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %acc = select <4 x i1> %tmp1, <4 x i32> %add, <4 x i32> %vec.phi
  %reduce = call i32 @llvm.experimental.vector.reduce.add.v4i32(<4 x i32> %acc)
  br label %for.cond.cleanup

for.cond.cleanup:                                 ; preds = %middle.block, %entry
  %res.0.lcssa = phi i32 [ 0, %entry ], [ %reduce, %middle.block ]
  ret i32 %res.0.lcssa
}

define dso_local i32 @or_mul_reduce_add(i32* noalias nocapture readonly %a, i32* noalias nocapture readonly %b, i32* noalias nocapture readonly %c, i32* noalias nocapture readonly %d, i32 %N) {
; CHECK-LABEL: or_mul_reduce_add:
; CHECK:       @ %bb.0: @ %entry
; CHECK-NEXT:    push {r4, r5, r7, lr}
; CHECK-NEXT:    ldr.w r12, [sp, #16]
; CHECK-NEXT:    cmp.w r12, #0
; CHECK-NEXT:    beq .LBB3_4
; CHECK-NEXT:  @ %bb.1: @ %vector.ph
; CHECK-NEXT:    add.w r4, r12, #3
; CHECK-NEXT:    vmov.i32 q1, #0x0
; CHECK-NEXT:    bic r4, r4, #3
; CHECK-NEXT:    subs r5, r4, #4
; CHECK-NEXT:    movs r4, #1
; CHECK-NEXT:    add.w lr, r4, r5, lsr #2
; CHECK-NEXT:    lsrs r4, r5, #2
; CHECK-NEXT:    sub.w r4, r12, r4, lsl #2
; CHECK-NEXT:    dls lr, lr
; CHECK-NEXT:  .LBB3_2: @ %vector.body
; CHECK-NEXT:    @ =>This Inner Loop Header: Depth=1
; CHECK-NEXT:    vctp.32 r12
; CHECK-NEXT:    vmov q0, q1
; CHECK-NEXT:    vpstt
; CHECK-NEXT:    vldrwt.u32 q1, [r1], #16
; CHECK-NEXT:    vldrwt.u32 q2, [r0], #16
; CHECK-NEXT:    vpnot
; CHECK-NEXT:    vsub.i32 q1, q2, q1
; CHECK-NEXT:    sub.w r12, r12, #4
; CHECK-NEXT:    vpstee
; CHECK-NEXT:    vcmpt.i32 ne, q1, zr
; CHECK-NEXT:    vldrwe.u32 q1, [r3], #16
; CHECK-NEXT:    vldrwe.u32 q2, [r2], #16
; CHECK-NEXT:    vmul.i32 q1, q2, q1
; CHECK-NEXT:    vadd.i32 q1, q1, q0
; CHECK-NEXT:    le lr, .LBB3_2
; CHECK-NEXT:  @ %bb.3: @ %middle.block
; CHECK-NEXT:    vctp.32 r4
; CHECK-NEXT:    vpsel q0, q1, q0
; CHECK-NEXT:    vaddv.u32 r0, q0
; CHECK-NEXT:    pop {r4, r5, r7, pc}
; CHECK-NEXT:  .LBB3_4:
; CHECK-NEXT:    movs r0, #0
; CHECK-NEXT:    pop {r4, r5, r7, pc}
entry:
  %cmp8 = icmp eq i32 %N, 0
  br i1 %cmp8, label %for.cond.cleanup, label %vector.ph

vector.ph:                                        ; preds = %entry
  %n.rnd.up = add i32 %N, 3
  %n.vec = and i32 %n.rnd.up, -4
  %trip.count.minus.1 = add i32 %N, -1
  %broadcast.splatinsert11 = insertelement <4 x i32> undef, i32 %trip.count.minus.1, i32 0
  %broadcast.splat12 = shufflevector <4 x i32> %broadcast.splatinsert11, <4 x i32> undef, <4 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i32 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %vec.phi = phi <4 x i32> [ zeroinitializer, %vector.ph ], [ %add, %vector.body ]
  %broadcast.splatinsert = insertelement <4 x i32> undef, i32 %index, i32 0
  %broadcast.splat = shufflevector <4 x i32> %broadcast.splatinsert, <4 x i32> undef, <4 x i32> zeroinitializer
  %induction = add <4 x i32> %broadcast.splat, <i32 0, i32 1, i32 2, i32 3>
  %tmp = getelementptr inbounds i32, i32* %a, i32 %index
  %tmp1 = icmp ule <4 x i32> %induction, %broadcast.splat12
  %tmp2 = bitcast i32* %tmp to <4 x i32>*
  %wide.masked.load.a = call <4 x i32> @llvm.masked.load.v4i32.p0v4i32(<4 x i32>* %tmp2, i32 4, <4 x i1> %tmp1, <4 x i32> undef)
  %tmp3 = getelementptr inbounds i32, i32* %b, i32 %index
  %tmp4 = bitcast i32* %tmp3 to <4 x i32>*
  %wide.masked.load.b = call <4 x i32> @llvm.masked.load.v4i32.p0v4i32(<4 x i32>* %tmp4, i32 4, <4 x i1> %tmp1, <4 x i32> undef)
  %sub = sub <4 x i32> %wide.masked.load.a, %wide.masked.load.b
  %cmp = icmp eq <4 x i32> %sub, <i32 0, i32 0, i32 0, i32 0>
  %mask = or <4 x i1> %cmp, %tmp1
  %tmp5 = getelementptr inbounds i32, i32* %c, i32 %index
  %tmp6 = bitcast i32* %tmp5 to <4 x i32>*
  %wide.masked.load.c = call <4 x i32> @llvm.masked.load.v4i32.p0v4i32(<4 x i32>* %tmp6, i32 4, <4 x i1> %mask, <4 x i32> undef)
  %tmp7 = getelementptr inbounds i32, i32* %d, i32 %index
  %tmp8 = bitcast i32* %tmp7 to <4 x i32>*
  %wide.masked.load.d = call <4 x i32> @llvm.masked.load.v4i32.p0v4i32(<4 x i32>* %tmp8, i32 4, <4 x i1> %mask, <4 x i32> undef)
  %mul = mul  <4 x i32> %wide.masked.load.c, %wide.masked.load.d
  %add = add  <4 x i32> %mul, %vec.phi
  %index.next = add i32 %index, 4
  %cmp.exit = icmp eq i32 %index.next, %n.vec
  br i1 %cmp.exit, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %acc = select <4 x i1> %tmp1, <4 x i32> %add, <4 x i32> %vec.phi
  %reduce = call i32 @llvm.experimental.vector.reduce.add.v4i32(<4 x i32> %acc)
  br label %for.cond.cleanup

for.cond.cleanup:                                 ; preds = %middle.block, %entry
  %res.0.lcssa = phi i32 [ 0, %entry ], [ %reduce, %middle.block ]
  ret i32 %res.0.lcssa
}

define dso_local void @continue_on_zero(i32* noalias nocapture %arg, i32* noalias nocapture readonly %arg1, i32 %arg2) {
; CHECK-LABEL: continue_on_zero:
; CHECK:       @ %bb.0: @ %bb
; CHECK-NEXT:    push {r7, lr}
; CHECK-NEXT:    cmp r2, #0
; CHECK-NEXT:    it eq
; CHECK-NEXT:    popeq {r7, pc}
; CHECK-NEXT:    dlstp.32 lr, r2
; CHECK-NEXT:  .LBB4_1: @ %bb9
; CHECK-NEXT:    @ =>This Inner Loop Header: Depth=1
; CHECK-NEXT:    vldrw.u32 q0, [r1], #16
; CHECK-NEXT:    vcmp.i32 ne, q0, zr
; CHECK-NEXT:    vpst
; CHECK-NEXT:    vldrwt.u32 q1, [r0]
; CHECK-NEXT:    vmul.i32 q0, q1, q0
; CHECK-NEXT:    vpst
; CHECK-NEXT:    vstrwt.32 q0, [r0], #16
; CHECK-NEXT:    letp lr, .LBB4_1
; CHECK-NEXT:  @ %bb.2: @ %bb27
; CHECK-NEXT:    pop {r7, pc}
bb:
  %tmp = icmp eq i32 %arg2, 0
  br i1 %tmp, label %bb27, label %bb3

bb3:                                              ; preds = %bb
  %tmp4 = add i32 %arg2, 3
  %tmp5 = and i32 %tmp4, -4
  %tmp6 = add i32 %arg2, -1
  %tmp7 = insertelement <4 x i32> undef, i32 %tmp6, i32 0
  %tmp8 = shufflevector <4 x i32> %tmp7, <4 x i32> undef, <4 x i32> zeroinitializer
  br label %bb9

bb9:                                              ; preds = %bb9, %bb3
  %tmp10 = phi i32 [ 0, %bb3 ], [ %tmp25, %bb9 ]
  %tmp11 = insertelement <4 x i32> undef, i32 %tmp10, i32 0
  %tmp12 = shufflevector <4 x i32> %tmp11, <4 x i32> undef, <4 x i32> zeroinitializer
  %tmp13 = add <4 x i32> %tmp12, <i32 0, i32 1, i32 2, i32 3>
  %tmp14 = getelementptr inbounds i32, i32* %arg1, i32 %tmp10
  %tmp15 = icmp ule <4 x i32> %tmp13, %tmp8
  %tmp16 = bitcast i32* %tmp14 to <4 x i32>*
  %tmp17 = call <4 x i32> @llvm.masked.load.v4i32.p0v4i32(<4 x i32>* %tmp16, i32 4, <4 x i1> %tmp15, <4 x i32> undef)
  %tmp18 = icmp ne <4 x i32> %tmp17, zeroinitializer
  %tmp19 = getelementptr inbounds i32, i32* %arg, i32 %tmp10
  %tmp20 = and <4 x i1> %tmp18, %tmp15
  %tmp21 = bitcast i32* %tmp19 to <4 x i32>*
  %tmp22 = call <4 x i32> @llvm.masked.load.v4i32.p0v4i32(<4 x i32>* %tmp21, i32 4, <4 x i1> %tmp20, <4 x i32> undef)
  %tmp23 = mul nsw <4 x i32> %tmp22, %tmp17
  %tmp24 = bitcast i32* %tmp19 to <4 x i32>*
  call void @llvm.masked.store.v4i32.p0v4i32(<4 x i32> %tmp23, <4 x i32>* %tmp24, i32 4, <4 x i1> %tmp20)
  %tmp25 = add i32 %tmp10, 4
  %tmp26 = icmp eq i32 %tmp25, %tmp5
  br i1 %tmp26, label %bb27, label %bb9

bb27:                                             ; preds = %bb9, %bb
  ret void
}

define dso_local arm_aapcs_vfpcc void @range_test(i32* noalias nocapture %arg, i32* noalias nocapture readonly %arg1, i32 %arg2, i32 %arg3) {
; CHECK-LABEL: range_test:
; CHECK:       @ %bb.0: @ %bb
; CHECK-NEXT:    push {r7, lr}
; CHECK-NEXT:    cmp r3, #0
; CHECK-NEXT:    it eq
; CHECK-NEXT:    popeq {r7, pc}
; CHECK-NEXT:    add.w r12, r3, #3
; CHECK-NEXT:    mov.w lr, #1
; CHECK-NEXT:    bic r12, r12, #3
; CHECK-NEXT:    sub.w r12, r12, #4
; CHECK-NEXT:    add.w lr, lr, r12, lsr #2
; CHECK-NEXT:    dls lr, lr
; CHECK-NEXT:  .LBB5_1: @ %bb12
; CHECK-NEXT:    @ =>This Inner Loop Header: Depth=1
; CHECK-NEXT:    vctp.32 r3
; CHECK-NEXT:    vpst
; CHECK-NEXT:    vldrwt.u32 q0, [r0]
; CHECK-NEXT:    vpttt.i32 ne, q0, zr
; CHECK-NEXT:    vcmpt.s32 le, q0, r2
; CHECK-NEXT:    vctpt.32 r3
; CHECK-NEXT:    vldrwt.u32 q1, [r1], #16
; CHECK-NEXT:    subs r3, #4
; CHECK-NEXT:    vmul.i32 q0, q1, q0
; CHECK-NEXT:    vpst
; CHECK-NEXT:    vstrwt.32 q0, [r0], #16
; CHECK-NEXT:    le lr, .LBB5_1
; CHECK-NEXT:  @ %bb.2: @ %bb32
; CHECK-NEXT:    pop {r7, pc}
bb:
  %tmp = icmp eq i32 %arg3, 0
  br i1 %tmp, label %bb32, label %bb4

bb4:                                              ; preds = %bb
  %tmp5 = add i32 %arg3, 3
  %tmp6 = and i32 %tmp5, -4
  %tmp7 = add i32 %arg3, -1
  %tmp8 = insertelement <4 x i32> undef, i32 %tmp7, i32 0
  %tmp9 = shufflevector <4 x i32> %tmp8, <4 x i32> undef, <4 x i32> zeroinitializer
  %tmp10 = insertelement <4 x i32> undef, i32 %arg2, i32 0
  %tmp11 = shufflevector <4 x i32> %tmp10, <4 x i32> undef, <4 x i32> zeroinitializer
  br label %bb12

bb12:                                             ; preds = %bb12, %bb4
  %tmp13 = phi i32 [ 0, %bb4 ], [ %tmp30, %bb12 ]
  %tmp14 = insertelement <4 x i32> undef, i32 %tmp13, i32 0
  %tmp15 = shufflevector <4 x i32> %tmp14, <4 x i32> undef, <4 x i32> zeroinitializer
  %tmp16 = add <4 x i32> %tmp15, <i32 0, i32 1, i32 2, i32 3>
  %tmp17 = getelementptr inbounds i32, i32* %arg, i32 %tmp13
  %tmp18 = icmp ule <4 x i32> %tmp16, %tmp9
  %tmp19 = bitcast i32* %tmp17 to <4 x i32>*
  %tmp20 = call <4 x i32> @llvm.masked.load.v4i32.p0v4i32(<4 x i32>* %tmp19, i32 4, <4 x i1> %tmp18, <4 x i32> undef)
  %tmp21 = icmp ne <4 x i32> %tmp20, zeroinitializer
  %tmp22 = icmp sle <4 x i32> %tmp20, %tmp11
  %tmp23 = getelementptr inbounds i32, i32* %arg1, i32 %tmp13
  %tmp24 = and <4 x i1> %tmp22, %tmp21
  %tmp25 = and <4 x i1> %tmp24, %tmp18
  %tmp26 = bitcast i32* %tmp23 to <4 x i32>*
  %tmp27 = call <4 x i32> @llvm.masked.load.v4i32.p0v4i32(<4 x i32>* %tmp26, i32 4, <4 x i1> %tmp25, <4 x i32> undef)
  %tmp28 = mul nsw <4 x i32> %tmp27, %tmp20
  %tmp29 = bitcast i32* %tmp17 to <4 x i32>*
  call void @llvm.masked.store.v4i32.p0v4i32(<4 x i32> %tmp28, <4 x i32>* %tmp29, i32 4, <4 x i1> %tmp25)
  %tmp30 = add i32 %tmp13, 4
  %tmp31 = icmp eq i32 %tmp30, %tmp6
  br i1 %tmp31, label %bb32, label %bb12

bb32:                                             ; preds = %bb12, %bb
  ret void
}

; Function Attrs: argmemonly nounwind readonly willreturn
declare <4 x i32> @llvm.masked.load.v4i32.p0v4i32(<4 x i32>*, i32 immarg, <4 x i1>, <4 x i32>)
declare void @llvm.masked.store.v4i32.p0v4i32(<4 x i32>, <4 x i32>*, i32, <4 x i1>)

; Function Attrs: nounwind readnone willreturn
declare i32 @llvm.experimental.vector.reduce.add.v4i32(<4 x i32>)
