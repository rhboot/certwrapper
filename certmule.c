// SPDX-License-Identifier: BSD-2-Clause-Patent
/*
 * certmule.c - a certificate wrapper for EFI security databases
 *
 * Author(s): Peter Jones <pjones@redhat.com>
 */

#include <efi.h>
#include <efilib.h>

/*
 * siiigh...
 * Make sure it's relocatable, or else the EFI loader will error.
 */
__asm__(
".section .reloc, \"a\"\n"
"	.long	0\n"			// Page RVA
"	.long	10\n"			// Block Size (2*4+2)
"	.word	0\n"			// Relocation offset
".text\n"
);

EFI_STATUS
_start(EFI_HANDLE image_handle __attribute__((__unused__)),
       EFI_SYSTEM_TABLE *systab __attribute__((__unused__)))
{
	return EFI_SECURITY_VIOLATION;
}

// vim:fenc=utf-8:tw=75:noet
