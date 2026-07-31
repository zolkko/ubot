/* nRF52840, S140 SoftDevice v7.3.0 reserves the low flash/RAM regions below.
   Adjust ORIGIN/LENGTH if you flash a different SoftDevice version. */
MEMORY
{
  FLASH : ORIGIN = 0x00027000, LENGTH = 868K
  RAM   : ORIGIN = 0x20020000, LENGTH = 128K
}
