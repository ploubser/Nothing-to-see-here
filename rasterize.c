#include "rasterize.h"

void toMatrix(char *Filename)
{
    FILE *ImageFile;
    BITMAPFILEHEADER bmfh;
    BITMAPINFOHEADER bmih;
    unsigned char *Array;
  
    ImageFile = fopen(Filename, "rb");

    fread(&bmfh, sizeof(BITMAPFILEHEADER), 1, ImageFile);
    fread(&bmih, sizeof(BITMAPINFOHEADER), 1, ImageFile);
    
    Array = (unsigned char*)calloc(((bmih.biHeight * bmih.biWidth) * 3), sizeof(unsigned char));

    int i;

    for(i = 0; i < ((bmih.biHeight * bmih.biWidth) * 3); i += 3)
        fread(&Array[i], sizeof(unsigned char[3]), 1, ImageFile);

    fclose(ImageFile);
    
    if(bmfh.bfType == 0x4D42)
    {
        printf("File Header\n");
        printf("Type : %x\n", bmfh.bfType); 
        printf("Size : %x\n", bmfh.bfSize);
        printf("Reserved1 : %x\n", bmfh.bfReserved1); 
        printf("Reserved2 : %x\n", bmfh.bfReserved2);
        printf("OffBits : %x\n", bmfh.bfOffBits); 

        printf("\nInfo Header \n");
        printf("Size : %x\n", bmih.biSize);
        printf("Width : %x\n", bmih.biWidth);
        printf("Height : %x\n", bmih.biHeight);
        printf("Planes : %x\n", bmih.biPlanes);
        printf("BitCount : %x\n", bmih.biBitCount);
        printf("Compression : %x\n", bmih.biCompression);
        printf("SizeImage : %x\n", bmih.biSizeImage);
        printf("XpelsPerMeter : %x\n", bmih.biXPelsPerMeter);
        printf("YpelsPerMeter : %x\n", bmih.biYPelsPerMeter);
        printf("ClrUsed : %x\n", bmih.biClrUsed);
        printf("ClrImportant : %x\n", bmih.biClrImportant);
    
        FILE *fptr;
        fptr = fopen("dump.bmp", "w");
        fwrite(&bmfh, sizeof(bmfh), 1, fptr);
        fwrite(&bmih, sizeof(bmih), 1, fptr);
        fwrite(Array, sizeof(unsigned char*), bmih.biWidth * bmih.biHeight, fptr);

    fclose(fptr);


    }
    else
    {
        printf("Invalid Bitmap file.\n");
    }

}
