//
//  main.mm
//  HelloFFmpeg
//
//  Created by burt on 2014. 2. 13..
//  Copyright (c) 2014년 burt. All rights reserved.
//

#include "main.h"
#include <SDL/SDL.h>
#include <SDL/SDL_thread.h>
#include "SDLMain.h"

/**
 @see http://stackoverflow.com/questions/4585847/g-linking-error-on-mac-while-compiling-ffmpeg
 */
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswscale/swscale.h>
}

int main(int argc, char **argv)
{
	AVFormatContext *pFormatCtx = NULL;
	int             i, videoStream;
	AVCodecContext  *pCodecCtx = NULL;
	AVCodec         *pCodec = NULL;
	AVFrame         *pFrame = NULL;
	AVPacket        packet;
	int             frameFinished;
	float           aspect_ratio;
	int				sws_flags = SWS_BICUBIC;
	struct SwsContext *img_convert_ctx = NULL;

	
	SDL_Overlay     *bmp = NULL;
	SDL_Surface     *screen = NULL;
	SDL_Rect        rect;
	SDL_Event       event;

	if( argc < 2 )
	{
		fprintf(stderr, "Usage: test <file>\n");
		exit(1);
	}
	
	av_register_all();

	if(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_TIMER))
	{
		fprintf(stderr, "Could not initialize SDL - %s\n", SDL_GetError());
		exit(1);
	}
	
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
	
	// Allocate video frame
	pFrame = avcodec_alloc_frame();
	
	screen = SDL_SetVideoMode(pCodecCtx->width, pCodecCtx->height, 0, 0);
	if(!screen)
	{
		fprintf(stderr, "SDL: could not set video mode - exiting\n");
		exit(1);
	}
	
	bmp = SDL_CreateYUVOverlay(pCodecCtx->width, pCodecCtx->height, SDL_YV12_OVERLAY, screen);
	
	i=0;
	while (av_read_frame(pFormatCtx, &packet) >= 0) {
		if(packet.stream_index == videoStream)
		{
			// Decode video frame
			avcodec_decode_video2(pCodecCtx, pFrame, &frameFinished, &packet);
			if(frameFinished)
			{
				SDL_LockYUVOverlay(bmp);
				
				AVPicture pict;
				pict.data[0] = bmp->pixels[0];
				pict.data[1] = bmp->pixels[2];
				pict.data[2] = bmp->pixels[1];
				
				pict.linesize[0] = bmp->pitches[0];
				pict.linesize[1] = bmp->pitches[2];
				pict.linesize[2] = bmp->pitches[1];
				
				// Convert the image into YUV format that SDL uses
				img_convert_ctx = sws_getContext(pCodecCtx->width, pCodecCtx->height, pCodecCtx->pix_fmt, pCodecCtx->width, pCodecCtx->height, PIX_FMT_YUV420P, sws_flags, NULL, NULL, NULL);
				sws_scale(img_convert_ctx, pFrame->data, pFrame->linesize, 0, pCodecCtx->height, pict.data, pict.linesize);
				sws_freeContext(img_convert_ctx);
				
				SDL_UnlockYUVOverlay(bmp);
				
				rect.x = 0;
				rect.y = 0;
				rect.w = pCodecCtx->width;
				rect.h = pCodecCtx->height;
				
				SDL_DisplayYUVOverlay(bmp, &rect);
			}
		}
		
		//Free the packet that was allocated by av_read_frame
		av_free_packet(&packet);
		SDL_PollEvent(&event);
		switch (event.type)
		{
			case SDL_QUIT:
				SDL_Quit();
				break;
			default:
				break;
		}
	}
	
	// Free the YUV frame
	av_free(pFrame);
	
	// Close the codec
	avcodec_close(pCodecCtx);
	
	// Close the video file
	avformat_close_input(&pFormatCtx);
	return 0;
}
