//===-- VEISelDAGToDAG.cpp - A dag to dag inst selector for VE ------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file defines an instruction selector for the VE target.
//
//===----------------------------------------------------------------------===//

#include "VETargetMachine.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"
#include "llvm/CodeGen/SelectionDAGISel.h"
#include "llvm/IR/Intrinsics.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/raw_ostream.h"
using namespace llvm;

//===----------------------------------------------------------------------===//
// Instruction Selector Implementation
//===----------------------------------------------------------------------===//

//===--------------------------------------------------------------------===//
/// VEDAGToDAGISel - VE specific code to select VE machine
/// instructions for SelectionDAG operations.
///
namespace {
class VEDAGToDAGISel : public SelectionDAGISel {
  /// Subtarget - Keep a pointer to the VE Subtarget around so that we can
  /// make the right decision when generating code for different targets.
  const VESubtarget *Subtarget;

public:
  explicit VEDAGToDAGISel(VETargetMachine &tm) : SelectionDAGISel(tm) {}

  bool runOnMachineFunction(MachineFunction &MF) override {
    Subtarget = &MF.getSubtarget<VESubtarget>();
    return SelectionDAGISel::runOnMachineFunction(MF);
  }

  void Select(SDNode *N) override;

  // Complex Pattern Selectors.
  bool selectADDRrri(SDValue N, SDValue &Base, SDValue &Index, SDValue &Offset);
  bool selectADDRrii(SDValue N, SDValue &Base, SDValue &Index, SDValue &Offset);
  bool selectADDRzri(SDValue N, SDValue &Base, SDValue &Index, SDValue &Offset);
  bool selectADDRzii(SDValue N, SDValue &Base, SDValue &Index, SDValue &Offset);
  bool selectADDRri(SDValue N, SDValue &Base, SDValue &Offset);

  StringRef getPassName() const override {
    return "VE DAG->DAG Pattern Instruction Selection";
  }

  // Include the pieces autogenerated from the target description.
#include "VEGenDAGISel.inc"

private:
  SDNode *getGlobalBaseReg();

  bool matchADDRrr(SDValue N, SDValue &Base, SDValue &Index);
  bool matchADDRri(SDValue N, SDValue &Base, SDValue &Offset);
};
} // end anonymous namespace

bool VEDAGToDAGISel::selectADDRrri(SDValue Addr, SDValue &Base, SDValue &Index,
                                   SDValue &Offset) {
  if (Addr.getOpcode() == ISD::FrameIndex)
    return false;
  if (Addr.getOpcode() == ISD::TargetExternalSymbol ||
      Addr.getOpcode() == ISD::TargetGlobalAddress ||
      Addr.getOpcode() == ISD::TargetGlobalTLSAddress)
    return false; // direct calls.

  SDValue LHS, RHS;
  if (matchADDRri(Addr, LHS, RHS)) {
    if (matchADDRrr(LHS, Base, Index)) {
      Offset = RHS;
      return true;
    }
    // Return false to try selectADDRrii.
    return false;
  }
  if (matchADDRrr(Addr, LHS, RHS)) {
    if (matchADDRri(RHS, Index, Offset)) {
      Base = LHS;
      return true;
    }
    if (matchADDRri(LHS, Base, Offset)) {
      Index = RHS;
      return true;
    }
    Base = LHS;
    Index = RHS;
    Offset = CurDAG->getTargetConstant(0, SDLoc(Addr), MVT::i32);
    return true;
  }
  return false; // Let the reg+imm(=0) pattern catch this!
}

bool VEDAGToDAGISel::selectADDRrii(SDValue Addr, SDValue &Base, SDValue &Index,
                                   SDValue &Offset) {
  if (matchADDRri(Addr, Base, Offset)) {
    Index = CurDAG->getTargetConstant(0, SDLoc(Addr), MVT::i32);
    return true;
  }

  Base = Addr;
  Index = CurDAG->getTargetConstant(0, SDLoc(Addr), MVT::i32);
  Offset = CurDAG->getTargetConstant(0, SDLoc(Addr), MVT::i32);
  return true;
}

bool VEDAGToDAGISel::selectADDRzri(SDValue Addr, SDValue &Base, SDValue &Index,
                                   SDValue &Offset) {
  // Prefer ADDRrii.
  return false;
}

bool VEDAGToDAGISel::selectADDRzii(SDValue Addr, SDValue &Base, SDValue &Index,
                                   SDValue &Offset) {
  if (dyn_cast<FrameIndexSDNode>(Addr)) {
    return false;
  }
  if (Addr.getOpcode() == ISD::TargetExternalSymbol ||
      Addr.getOpcode() == ISD::TargetGlobalAddress ||
      Addr.getOpcode() == ISD::TargetGlobalTLSAddress)
    return false; // direct calls.

  if (ConstantSDNode *CN = cast<ConstantSDNode>(Addr)) {
    if (isInt<32>(CN->getSExtValue())) {
      Base = CurDAG->getTargetConstant(0, SDLoc(Addr), MVT::i32);
      Index = CurDAG->getTargetConstant(0, SDLoc(Addr), MVT::i32);
      Offset =
          CurDAG->getTargetConstant(CN->getZExtValue(), SDLoc(Addr), MVT::i32);
      return true;
    }
  }
  return false;
}

bool VEDAGToDAGISel::selectADDRri(SDValue Addr, SDValue &Base,
                                  SDValue &Offset) {
  if (matchADDRri(Addr, Base, Offset))
    return true;

  Base = Addr;
  Offset = CurDAG->getTargetConstant(0, SDLoc(Addr), MVT::i32);
  return true;
}

bool VEDAGToDAGISel::matchADDRrr(SDValue Addr, SDValue &Base, SDValue &Index) {
  if (dyn_cast<FrameIndexSDNode>(Addr))
    return false;
  if (Addr.getOpcode() == ISD::TargetExternalSymbol ||
      Addr.getOpcode() == ISD::TargetGlobalAddress ||
      Addr.getOpcode() == ISD::TargetGlobalTLSAddress)
    return false; // direct calls.

  if (Addr.getOpcode() == ISD::ADD) {
    ; // Nothing to do here.
  } else if (Addr.getOpcode() == ISD::OR) {
    // We want to look through a transform in InstCombine and DAGCombiner that
    // turns 'add' into 'or', so we can treat this 'or' exactly like an 'add'.
    if (!CurDAG->haveNoCommonBitsSet(Addr.getOperand(0), Addr.getOperand(1)))
      return false;
  } else {
    return false;
  }

  if (Addr.getOperand(0).getOpcode() == VEISD::Lo ||
      Addr.getOperand(1).getOpcode() == VEISD::Lo)
    return false; // Let the LEASL patterns catch this!

  Base = Addr.getOperand(0);
  Index = Addr.getOperand(1);
  return true;
}

bool VEDAGToDAGISel::matchADDRri(SDValue Addr, SDValue &Base, SDValue &Offset) {
  auto AddrTy = Addr->getValueType(0);
  if (FrameIndexSDNode *FIN = dyn_cast<FrameIndexSDNode>(Addr)) {
    Base = CurDAG->getTargetFrameIndex(FIN->getIndex(), AddrTy);
    Offset = CurDAG->getTargetConstant(0, SDLoc(Addr), MVT::i32);
    return true;
  }
  if (Addr.getOpcode() == ISD::TargetExternalSymbol ||
      Addr.getOpcode() == ISD::TargetGlobalAddress ||
      Addr.getOpcode() == ISD::TargetGlobalTLSAddress)
    return false; // direct calls.

  if (CurDAG->isBaseWithConstantOffset(Addr)) {
    ConstantSDNode *CN = cast<ConstantSDNode>(Addr.getOperand(1));
    if (isInt<32>(CN->getSExtValue())) {
      if (FrameIndexSDNode *FIN =
              dyn_cast<FrameIndexSDNode>(Addr.getOperand(0))) {
        // Constant offset from frame ref.
        Base = CurDAG->getTargetFrameIndex(FIN->getIndex(), AddrTy);
      } else {
        Base = Addr.getOperand(0);
      }
      Offset =
          CurDAG->getTargetConstant(CN->getZExtValue(), SDLoc(Addr), MVT::i32);
      return true;
    }
  }
  return false;
}

void VEDAGToDAGISel::Select(SDNode *N) {
  SDLoc dl(N);
  if (N->isMachineOpcode()) {
    N->setNodeId(-1);
    return; // Already selected.
  }

  switch (N->getOpcode()) {
  case VEISD::GLOBAL_BASE_REG:
    ReplaceNode(N, getGlobalBaseReg());
    return;
  }

  SelectCode(N);
}

SDNode *VEDAGToDAGISel::getGlobalBaseReg() {
  Register GlobalBaseReg = Subtarget->getInstrInfo()->getGlobalBaseReg(MF);
  return CurDAG
      ->getRegister(GlobalBaseReg, TLI->getPointerTy(CurDAG->getDataLayout()))
      .getNode();
}

/// createVEISelDag - This pass converts a legalized DAG into a
/// VE-specific DAG, ready for instruction scheduling.
///
FunctionPass *llvm::createVEISelDag(VETargetMachine &TM) {
  return new VEDAGToDAGISel(TM);
}
