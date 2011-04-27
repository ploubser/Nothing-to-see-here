#ifndef RASTERIZE_H
#define RATSERIZE_H

#include "stdio.h"
#include "stdlib.h"
#include "stdint.h"

#pragma pack(push,1)

typedef uint16_t WORD;
typedef uint32_t DWORD;

typedef struct tagBITMAPFILEHEADER
{
    WORD bfType;
    DWORD bfSize;
    WORD bfReserved1;
    WORD bfReserved2;
    DWORD bfOffBits;
} BITMAPFILEHEADER;

typedef struct tagBITMAPINFOHEADER
{
    DWORD  biSize; 
    DWORD  biWidth; 
    DWORD  biHeight; 
    WORD   biPlanes; 
    WORD   biBitCount; 
    DWORD  biCompression; 
    DWORD  biSizeImage; 
    DWORD  biXPelsPerMeter; 
    DWORD  biYPelsPerMeter; 
    DWORD  biClrUsed; 
    DWORD  biClrImportant; 
} BITMAPINFOHEADER;

void toMatrix(char *);

#endif
