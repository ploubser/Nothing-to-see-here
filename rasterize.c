#include "rasterize.h"

void toMatrix(char *Filename)
{
    FILE *ImageFile;
    FILE *dptr;
    BITMAPFILEHEADER bmfh;
    BITMAPINFOHEADER bmih;
    unsigned char *Array;
    unsigned char **Mat;
    int i,j,k,count;
  
    ImageFile = fopen(Filename, "rb");

    fread(&bmfh, sizeof(BITMAPFILEHEADER), 1, ImageFile);
    fread(&bmih, sizeof(BITMAPINFOHEADER), 1, ImageFile);
    
    Array = (unsigned char*)calloc(((bmih.biSizeImage) * 3), sizeof(unsigned char));
    Mat = (unsigned char**)malloc(bmih.biHeight * bmih.biWidth * 3 * sizeof(unsigned char*));
    for (i = 0; i < bmih.biHeight; i++)
    	Mat[i]=(unsigned char*)(malloc(bmih.biWidth*sizeof(unsigned char)));

    for(i = 0; i < ((bmih.biSizeImage) * 3); i += 3)
      fread(&Array[i], sizeof(unsigned char[3]), 1, ImageFile);

    dptr = fopen("dump.txt","w");

   count = 0;
   printf("Creating Matrix...\n\n");
   for (i = bmih.biHeight-1; i >= 0; i--)
    {
    	for (j = 0; j < bmih.biWidth*3; j=j+3)
	{
		printf("i = %d  j = %d\n",i,j);
                Mat[i][j] = Array[count];
		count++;
		Mat[i][j+1] = Array[count];
		count++;
                Mat[i][j+2] = Array[count];
		count++;
	}
	for (k = 0; k < (bmih.biWidth % 4); k++)
		count++;
    }
    printf("Printing to file...\n\n");
    for (i = 0; i < bmih.biHeight; i++)
    {
        for (j = 0; j < bmih.biWidth*3; j=j+3)
        {
		printf("i = %d  j = %d\n",i,j);
		printf("[%d]", Mat[i][j]);
                printf("[%d]", Mat[i][j+1]);
                printf("[%d]\n", Mat[i][j+2]); 
		
		fprintf(dptr, "[%d]", Mat[i][j]);
           	fprintf(dptr, "[%d]", Mat[i][j+1]);
           	fprintf(dptr, "[%d]\n", Mat[i][j+2]);	
	}
	fprintf(dptr, "\n");
    }
    fclose(dptr);
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
