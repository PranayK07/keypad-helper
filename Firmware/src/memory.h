/* Keep SDCC interrupt and main-loop data accesses out of nonreentrant generic
 * pointer runtime helpers. On the host these are ordinary C pointers. */
#ifndef KPH_MEMORY_H
#define KPH_MEMORY_H
#ifdef __SDCC
#define KPH_XDATA __xdata
#else
#define KPH_XDATA
#endif
#endif
