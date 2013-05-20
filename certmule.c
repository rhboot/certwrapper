// SPDX-License-Identifier: BSD-2-Clause-Patent
/*
 * A simple EFI program to be used as a key-wrapping mechanism
 * Author(s): Peter Jones <pjones@redhat.com>
 */


#include <stdint.h>

#include <efi.h>
#include <efilib.h>

EFI_STATUS
efi_main(EFI_HANDLE image_handle, EFI_SYSTEM_TABLE *systab)
{
	InitializeLib(image_handle, systab);

	Print(L"This is a test application that should be completely safe.\n");

	return EFI_SUCCESS;
}
