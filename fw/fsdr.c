#pragma NOIV                    // Do not generate interrupt vectors
//-----------------------------------------------------------------------------
//   File:      slave.c
//   Contents:  Hooks required to implement USB peripheral function.
//              Code written for FX2 REVE 56-pin and above.
//              This firmware is used to demonstrate FX2 Slave FIF
//              operation.
//   Copyright (c) 2003 Cypress Semiconductor All rights reserved
//-----------------------------------------------------------------------------
#include "fx2.h"
#include "fx2regs.h"
#include "fx2sdly.h"            // SYNCDELAY macro

void FSDR_Configure()
{
  PORTACFG &= ~0x03; //PA0 and PA1 as regular GPIO
  OEA |= 0x01; //PA0 output
  OEA &= ~0x02; //PA1 input
}


void delay(unsigned long i)
{
  while (i--)
  {
    #pragma asm
	NOP
	#pragma endasm
  }
}

