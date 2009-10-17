/*****************************************************************************
 * Copyright (C) 2009 the VideoLAN team
 *
 * Authors: Pierre d'Herbemont
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#import "VLCExtendedVideoView.h"
#import "NSScreen_Additions.h"

@implementation VLCExtendedVideoView

- (VLCMediaPlayer*) mediaPlayer
{
    return _mediaPlayer;
}

- (void) setMediaPlayer:(VLCMediaPlayer *) mp
{
    _mediaPlayer = mp;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayError:) name:@"VLCMediaPlayerNoSignalNotification" object:nil];
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (BOOL)mouseDownCanMoveWindow
{
    return YES;
}

- (BOOL)isOpaque
{
    return YES;
}

- (void)displayError:(NSNotification *)aNotification
{
    NSView * VLCOpenGLVoutView = [[self subviews] objectAtIndex:0];
    NSImageView * errorView = [[NSImageView alloc] initWithFrame:[VLCOpenGLVoutView frame]];
    [errorView setBounds:[VLCOpenGLVoutView bounds]];
    NSImage * errorImage = [NSImage imageNamed:@"errorImage.svg"];
    [errorView setImage:errorImage];
    [self replaceSubview:VLCOpenGLVoutView with:errorView];
    [errorView release];
}
@end
