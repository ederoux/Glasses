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

#import <VLCKit/VLCKit.h>

#import "VLCStyledVideoWindowView.h"
#import "VLCStyledVideoWindowController.h"
#import "VLCExtendedVideoView.h"
#import "VLCStyledVideoWindow.h"
#import "VLCMediaDocument.h"
#import "DOMElement_Additions.h"
#import "DOMHTMLElement_Additions.h"

@interface  VLCStyledVideoWindowView ()
- (void)videoDidResize;
- (void)_removeBelowWindow;
@end

@implementation VLCStyledVideoWindowView
- (void)dealloc
{
    NSAssert(!_contentTracking, @"_contentTracking should have been released");
    NSAssert(!_videoWindow, @"_videoWindow should have been released");
    [super dealloc];
}

- (void)close
{
#if SUPPORT_VIDEO_BELOW_CONTENT
    [self _removeBelowWindow];
#endif
    [self removeTrackingArea:_contentTracking];
    [_contentTracking release];
    _contentTracking = nil;
    [super close];
}

- (void)awakeFromNib
{
    [self setup];    
}

- (void)setup
{
#if SUPPORT_VIDEO_BELOW_CONTENT
    // When a style is reloaded, this method gets called.
    // Clear the below window here.
    [self _removeBelowWindow];
#endif
    [super setup];
}

- (NSString *)pageName
{
    return @"video-window";
}

- (void)didFinishLoadForFrame:(WebFrame *)frame
{
    [super didFinishLoadForFrame:frame];

    NSWindow *window = [self window];
    [[self windowScriptObject] setValue:window forKey:@"PlatformWindow"];

    [window setIgnoresMouseEvents:NO];

    [self videoDidResize];
    [self setKeyWindow:[window isKeyWindow]];
    [self setMainWindow:[window isMainWindow]];
    [self updateTrackingAreas];
    
    [window performSelector:@selector(invalidateShadow) withObject:self afterDelay:0.];
    [window performSelector:@selector(display) withObject:self afterDelay:0.];
}

- (void)windowDidChangeAlphaValue:(CGFloat)alpha
{
    [_videoWindow setAlphaValue:alpha];
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
    return YES;
}

#pragma mark -
#pragma mark Core -> Javascript setters

- (void)setKeyWindow:(BOOL)isKeyWindow
{
    if (isKeyWindow)
        [self addClassToContent:@"key-window"];
    else
        [self removeClassFromContent:@"key-window"];

}

- (void)setMainWindow:(BOOL)isMainWindow
{
    if (isMainWindow)
        [self addClassToContent:@"main-window"];
    else
        [self removeClassFromContent:@"main-window"];
}

// Other setter are in super class.

#pragma mark -
#pragma mark Javascript callbacks

- (void)setPosition:(float)position
{
    [[self mediaPlayer] setPosition:position];
}

- (void)play
{    
    [[self mediaPlayer] play];
}

- (void)pause
{
    [[self mediaPlayer] pause];
}

#if SUPPORT_VIDEO_BELOW_CONTENT
static NSRect screenRectForViewRect(NSView *view, NSRect rect)
{
    NSRect screenRect = [view convertRect:rect toView:nil]; // Convert to Window base coord
    NSRect windowFrame = [[view window] frame];
    screenRect.origin.x += windowFrame.origin.x;
    screenRect.origin.y += windowFrame.origin.y;  
    return screenRect;
}
#endif

- (void)_removeBelowWindow
{
    if (_videoWindow)
        [[self window] removeChildWindow:_videoWindow];
    [_videoWindow close];
    [_videoWindow release];
    _videoWindow = nil;
}

- (void)_addBelowWindowInRect:(NSRect)screenRect withVideoView:(VLCVideoView *)videoView
{
    NSAssert(!_videoWindow, @"There should not be a video window at this point");

    // Create the window now.
    _videoWindow = [[NSWindow alloc] initWithContentRect:screenRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:YES];
    [_videoWindow setBackgroundColor:[NSColor blackColor]];
    [_videoWindow setLevel:VLCFullscreenHUDWindowLevel()];
    [_videoWindow setContentView:videoView];
    [_videoWindow setIgnoresMouseEvents:YES];
    [_videoWindow setReleasedWhenClosed:NO];
    [_videoWindow setAcceptsMouseMovedEvents:NO];
    [_videoWindow setHasShadow:NO];
    NSWindow *window = [self window];
    [_videoWindow setAlphaValue:[window alphaValue]];
    [window addChildWindow:_videoWindow ordered:NSWindowBelow];    
}

- (void)videoDidResize
{
    // This synchronize the VLCVideoView on top of the element whose id is "video-view"
    // When the style wants the video-view to be below the rest of the page, we
    // put the VLCVideoView in a Window that will be a child window.
    // Hence the HTML content will be able to overlay the window.
    //
    // When there is no such instruction, it will just be a regular NSView in the
    // parent window.

    DOMHTMLElement *element = [self htmlElementForId:@"video-view"];
    NSAssert(element, @"No video-view element in this style");
    VLCVideoView *videoView = [[[self window] windowController] videoView];
    NSAssert(videoView, @"There is no videoView.");

    NSRect frame = [element frameInView:self];

    // For now the playlist toggle uses this methog
    // to update the tracking area, so force it here.
    [self updateTrackingAreas];

#if SUPPORT_VIDEO_BELOW_CONTENT
    BOOL wantsBelowContent = [element.className rangeOfString:@"below-content"].length > 0;
    if (![videoView window]) {
        
        if (wantsBelowContent) {
            [self _addBelowWindowInRect:screenRectForViewRect(self, frame) withVideoView:videoView];
        }
        else {
            [self addSubview:videoView];
            [videoView setFrame:frame];
        }
        
    }
    else {
        BOOL videoIsOnTop = !_videoWindow;
        if (videoIsOnTop && !wantsBelowContent) {
            [videoView setFrame:frame];
            return;
        }
        if (!videoIsOnTop && wantsBelowContent) {
            [_videoWindow setFrame:screenRectForViewRect(self, frame) display:YES];
            return;
        }
        if (videoIsOnTop && wantsBelowContent) {
            [videoView removeFromSuperviewWithoutNeedingDisplay];
            [self _addBelowWindowInRect:screenRectForViewRect(self, frame) withVideoView:videoView];
            return;
        }
        if (!videoIsOnTop && !wantsBelowContent) {
            [videoView removeFromSuperviewWithoutNeedingDisplay];
            [self addSubview:videoView];
            [videoView setFrame:frame];
            [self _removeBelowWindow];
            return;
        }
        VLCAssertNotReached(@"Previous conditions should not lead here");
    }
#else
    if (![videoView superview])
        [self addSubview:videoView];
    [videoView setFrame:frame];
#endif
}

- (VLCMediaListPlayer *)mediaListPlayer
{
    return [[[[self window] windowController] document] mediaListPlayer];
}


- (VLCMediaListAspect *)rootMediaList
{
    VLCMediaListPlayer *player = [self mediaListPlayer];
    VLCMediaListAspect *mainMediaContent = player.rootMedia.subitems.flatAspect;
    BOOL isPlaylistDocument = mainMediaContent.count > 0;
    return isPlaylistDocument ? mainMediaContent : player.mediaList.flatAspect;
}

- (void)playMediaAtIndex:(NSUInteger)index
{
    [[self mediaListPlayer] playMedia:[[self rootMediaList] mediaAtIndex:index]];
}

- (NSString *)titleAtIndex:(NSUInteger)index
{
    return [[[[self rootMediaList] mediaAtIndex:index] metaDictionary] objectForKey:@"title"];
}

- (NSUInteger)count
{
    return [[self rootMediaList] count];
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)sel
{
    if (sel == @selector(playMediaAtIndex:))
        return NO;
    if (sel == @selector(titleAtIndex:))
        return NO;
    if (sel == @selector(count))
        return NO;
    if (sel == @selector(videoDidResize))
        return NO;
    if (sel == @selector(play))
        return NO;
    if (sel == @selector(pause))
        return NO;
    if (sel == @selector(setPosition:))
        return NO;
    
    return YES;
}

+ (BOOL)isKeyExcludedFromWebScript:(const char *)name
{
    return YES;
}

#pragma mark -
#pragma mark Tracking area

// Because the NSWindow that contains our WebView might have a lot
// of transparent area, we need to restrict click event in those area.
// The transparent area might be present because of some drop shadow.

- (void)mouseEntered:(NSEvent *)theEvent
{
    [[self window] setIgnoresMouseEvents:NO];
}

- (void)mouseExited:(NSEvent *)theEvent
{
    [[self window] setIgnoresMouseEvents:YES];
}

- (void)updateTrackingAreas
{
    if (!_isFrameLoaded) {
        [super updateTrackingAreas];
        return;
    }

    // Don't track ignored mouseEvents in debug window
   if ([VLCStyledVideoWindow debugStyledWindow])
       return;

    DOMElement *element = [self htmlElementForId:@"main-window"];

    NSAssert(element, @"No content element in this style");
    NSRect frame = [element frameInView:self];

    DOMHTMLElement *more = [self htmlElementForId:@"more" canBeNil:YES] ;
    if (more && [more hasClassName:@"visible"]) {
        NSRect frameMore = [more frameInView:self];
        frame = NSUnionRect(frameMore, frame);
    }

    if (!_contentTracking || !NSEqualRects([_contentTracking rect], frame)) {
        [self removeTrackingArea:_contentTracking];
        [_contentTracking release];
        _contentTracking = [[NSTrackingArea alloc] initWithRect:frame options:NSTrackingMouseEnteredAndExited|NSTrackingActiveAlways owner:self userInfo:nil];    
        [self addTrackingArea:_contentTracking];
    }
    
    [super updateTrackingAreas];
}

#pragma mark -
#pragma mark View methods

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (NSView *)hitTest:(NSPoint)point
{
    // Hit test function that ignores the videoView and forward everything
    // to the webview. This allows a full control over the behaviour of event
    // in the video view by the style.

    NSView *videoView = [[[self window] windowController] videoView];
    for (NSView *subview in [self subviews])
    {
        if (subview == videoView)
            continue;
        NSPoint localPoint = [subview convertPoint:point fromView:self];
        NSView *result = [subview hitTest:localPoint];
        if (result)
            return result;
    }

    return NSPointInRect(point, [self bounds]) ? self : nil;
}

@end
