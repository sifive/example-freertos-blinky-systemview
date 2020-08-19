/* Copyright 2019 SiFive, Inc */
/* SPDX-License-Identifier: Apache-2.0 */

/* FreeRTOS kernel includes. */
#include <FreeRTOS.h>

/* Freedom metal includes. */
#include <metal/exception.h>
#include <metal/platform.h>

#include <stdio.h>
#include <string.h>
#include <unistd.h>

#if( configUSE_SEGGER_SYSTEMVIEW == 1 )
# include "SEGGER_SYSVIEW_FreeRTOS.h"
#endif

static __attribute__ ((aligned(16))) StackType_t xISRStack[ configMINIMAL_STACK_SIZE ] __attribute__ ((section (".heap"))) = { 0 };
__attribute__ ((aligned(4))) uint8_t ucHeap[ configTOTAL_HEAP_SIZE ] __attribute__ ((section (".heap")));


__attribute__((constructor)) static void FreeRTOS_init(void);
#ifdef SEGGER_SYSTEMVIEW
__attribute__((constructor)) static void SEGGER_SysView_init(void);
#endif

__attribute__((constructor)) static void FreeRTOS_init(void)
{
	extern BaseType_t xPortFreeRTOSInit( StackType_t xIsrStack );
	
	/*
	* Call xPortFreeRTOSInit in order to set xISRTopStack
	*/
	if ( 0 != xPortFreeRTOSInit((StackType_t)&( xISRStack[ ( configMINIMAL_STACK_SIZE & ~portBYTE_ALIGNMENT_MASK ) - 1 ] ))) {
		_exit(-1);
	}
}


void FreedomMetal_InterruptHandler( portUBASE_TYPE hartid, portUBASE_TYPE mcause, portUBASE_TYPE mtvec )
{	
    __metal_interrupt_handler(mcause);
}

void FreedomMetal_ExceptionHandler( void )
{
    uintptr_t mcause;
    __asm__ volatile("csrr %0, mcause" : "=r"(mcause));
    __metal_exception_handler(mcause);
}

#if( configUSE_SEGGER_SYSTEMVIEW == 1 )
__attribute__((constructor)) static void SEGGER_SysView_init(void)
{
	SEGGER_SYSVIEW_Conf();
  SEGGER_SYSVIEW_Start();
}

U32 SEGGER_SYSVIEW_X_GetInterruptId(void) {
#if (__riscv_xlen == 64)
  uintptr_t mcause;

  __asm__ __volatile__ ("csrr %0, mcause" : "=r"(mcause));

  if (mcause & 0x8000000000000000)
    mcause = mcause & 0x7FFFFFFFFFFFFFFF;
  else
    mcause = mcause & 0x8000000000000000;

  return (U32)mcause;
#elif (__riscv_xlen == 32)
  uintptr_t mcause;

  __asm__ __volatile__ ("csrr %0, mcause" : "=r"(mcause));

  if (mcause & 0x80000000)
    mcause = mcause & 0x7FFFFFFF;
  else
    mcause = mcause & 0x80000000;

  return (U32)mcause;
#endif
}

#ifndef configCLINT_BASE_ADDRESS
  #error No CLINT Base Address defined
#endif

U32 SEGGER_SYSVIEW_X_GetTimestamp(void) {
#if (__riscv_xlen == 64)
  return (U32)(*(( uint64_t * volatile ) ( configCLINT_BASE_ADDRESS + 0xBFF8) ));
#elif (__riscv_xlen == 32) 
  uint32_t lo, hi;

    /* Guard against rollover when reading */
    do {
        hi = *(( uint32_t * volatile ) ( configCLINT_BASE_ADDRESS + 0xBFFC) );
        lo = *(( uint32_t * volatile ) ( configCLINT_BASE_ADDRESS + 0xBFF8) );
    } while ( *(( uint32_t * volatile ) ( configCLINT_BASE_ADDRESS + 0xBFFC)) != hi);

	return (U32)lo;
#endif
}

#endif
