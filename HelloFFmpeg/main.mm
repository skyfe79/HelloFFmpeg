//
//  main.mm
//  HelloFFmpeg
//
//  Created by burt on 2014. 2. 13..
//  Copyright (c) 2014년 burt. All rights reserved.
//

#include "main.h"
#include <SDL/SDL.h>
#include "SDLMain.h"

/**
 @see http://stackoverflow.com/questions/4585847/g-linking-error-on-mac-while-compiling-ffmpeg
 */
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswscale/swscale.h>
}

void SaveFrame(AVFrame *pFrame, int width, int height, int iFrame);

int main(int argc, char **argv)
{
	av_register_all();
	
	AVFormatContext *pFormatCtx = NULL;
	
	// Open video file
	if(avformat_open_input(&pFormatCtx, argv[1], 0, NULL) != 0)
	{
		// Couldn't open file
		return -1;
	}
	
	// Retrieve stream information
	if(avformat_find_stream_info(pFormatCtx, NULL) < 0)
	{
		// Couldn't find stream information
		return -1;
	}
	
	// Dump information about file onto standard error
	av_dump_format(pFormatCtx, 0, argv[1], 0);
	
	int i;
	int videoStream;
	AVCodecContext *pCodecCtx = NULL;
	
	//Find the first video stream
	videoStream = -1;
	for(i=0; i<pFormatCtx->nb_streams; i++)
	{
		if(pFormatCtx->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO)
		{
			videoStream = i;
			break;
		}
	}
	
	if(videoStream == -1)
	{
		// Didn't find a video stream
		return -1;
	}
	
	// Get a pointer to the codec context for the video stream
	pCodecCtx = pFormatCtx->streams[videoStream]->codec;
	
	
	AVCodec *pCodec = NULL;
	// Find the decoder for the video stream
	pCodec = avcodec_find_decoder(pCodecCtx->codec_id);
	if(pCodec == NULL)
	{
		// Codec not found
		fprintf(stderr, "Unsupported codec!\n");
		return -1;
	}
	
	//Open codec
	if(avcodec_open2(pCodecCtx, pCodec, NULL) < 0)
	{
		// Could not open codec
		return -1;
	}
	
	AVFrame *pFrame = NULL;
	AVFrame *pFrameRGB = NULL;
	//Allocate video frame
	pFrame = avcodec_alloc_frame();
	pFrameRGB = avcodec_alloc_frame();
	if(pFrameRGB == NULL)
		return -1;
	
	uint8_t *buffer = NULL;
	int numBytes;
	
	// Determine required buffer size and allocate buffer
	numBytes = avpicture_get_size(PIX_FMT_RGB24, pCodecCtx->width, pCodecCtx->height);
	buffer = (uint8_t*)av_malloc(numBytes * sizeof(uint8_t));
	
	
	// Assign appropriate parts of buffer to image planes in pFrameRGB
	// Note that pFrameRGB in an AVFrame, but AVFrame is a superset
	// of AVPicture
	avpicture_fill((AVPicture *)pFrameRGB, buffer, PIX_FMT_RGB24, pCodecCtx->width, pCodecCtx->height);
	
	int frameFinished;
	AVPacket packet;
	
	
	int sws_flags = SWS_BICUBIC;
	struct SwsContext *img_convert_ctx;
	
	i=0;
	while (av_read_frame(pFormatCtx, &packet) >= 0) {
		// Decode video frame
		avcodec_decode_video2(pCodecCtx, pFrame, &frameFinished, &packet);
		
		// Did we get a video frame?
		if(frameFinished)
		{
			// Convert the image from its native format to RGB
			//img_convert((AVPicture *)pFrameRGB, PIX_FMT_RGB24, (AVPicture *)pFrame, pCodecCtx->pix_fmt, pCodecCtx->width, pCodecCtx->height);
			img_convert_ctx = sws_getContext(pCodecCtx->width, pCodecCtx->height, pCodecCtx->pix_fmt, pCodecCtx->width, pCodecCtx->height, PIX_FMT_RGB24, sws_flags, NULL, NULL, NULL);
			sws_scale(img_convert_ctx, pFrame->data, pFrame->linesize, 0, pCodecCtx->height, pFrameRGB->data, pFrameRGB->linesize);
			sws_freeContext(img_convert_ctx);
			if(++i <= 5)
			{
				SaveFrame(pFrameRGB, pCodecCtx->width, pCodecCtx->height, i);
			}
		}
		//Free the packet that was allocated by av_read_frame
		av_free_packet(&packet);
	}
	
	// Free the RGB image
	av_free(buffer);
	av_free(pFrameRGB);
	
	// Free the YUV frame
	av_free(pFrame);
	
	// Close the codec
	avcodec_close(pCodecCtx);
	
	// Close the video file
	avformat_close_input(&pFormatCtx);
	return 0;
}


void SaveFrame(AVFrame *pFrame, int width, int height, int iFrame)
{
	FILE *pFile = NULL;
	char szFilename[32];
	int y;
	
	// Open file
	sprintf(szFilename, "frame%d.ppm", iFrame);
	pFile = fopen(szFilename, "wb");
	if(pFile == NULL)
		return;
	
	// Write header
	fprintf(pFile, "P6\n%d %d\n255\n", width, height);
	
	// Write pixel data
	for(y=0; y<height; y++)
	{
		fwrite(pFrame->data[0] + y * pFrame->linesize[0], 1, width * 3, pFile);
	}
	
	fclose(pFile);
}