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
}

int main(int argc, char **argv)
{
	av_register_all();
	return 0;
}