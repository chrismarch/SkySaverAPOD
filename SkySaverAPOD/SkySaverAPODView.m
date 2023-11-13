//
//  SkySaverAPODView.m
//  SkySaverAPOD
//
//  Created by Kristina Fedorenko on 7/25/20.
//  Copyright © 2020 Kristina Fedorenko. All rights reserved.
//

#import "SkySaverAPODView.h"
#import <QuartzCore/QuartzCore.h>

@implementation SkySaverAPODView


static NSRect mainRect;
static NSDictionary* APODdata;
static NSString* hdurl;
static NSImage* pic;

static NSString* desc;
static NSFont* font;
static NSDictionary* attributes;
static NSMutableParagraphStyle* paragraphStyle;
static NSRect picRect;
static NSUInteger desc_length;
static double font_fraction = 0.04;
static double img_height_by_width_ratio;
static NSSize img_size;
static NSScrollView* scrollView;
static NSImageView* imageView;
static NSSize imageViewOriginalSize;
static NSTextView *textView;
static CFTimeInterval startTime;
static NSRect textRect;

// for animation
static int zoom_fraq;
static int string_start;
static int update_zoom_by = 1;

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        [self setAnimationTimeInterval:1/60.0];
        
        zoom_fraq = 0;
        string_start = 0;
        mainRect = CGRectMake(0, 0, frame.size.width, frame.size.height);
        
        paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.alignment = NSTextAlignmentRight;
        paragraphStyle.headIndent = 10;

        NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd"];

        NSString *urlPrefix = @"https://api.nasa.gov/planetary/apod?api_key=v7ZYRL3q51GauWq1JYwg3ytoNDwm3ELnOGe7H6H8&date=";
        NSString *urlWithDate = [urlPrefix stringByAppendingString:[dateFormatter stringFromDate:[NSDate date]]];
        
        // request HTTP info
        // Create NSURLSession object
        NSURLSession *session = [NSURLSession sharedSession];

        // Create a NSURL object.
//        NSURL* url = [NSURL URLWithString:@"https://api.nasa.gov/planetary/apod?api_key=v7ZYRL3q51GauWq1JYwg3ytoNDwm3ELnOGe7H6H8&date=2020-07-24"];
          NSURL* url = [NSURL URLWithString:urlWithDate];

        // Create NSURLSessionDataTask task object by url and session object.
        NSURLSessionDataTask* task = [session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                
            APODdata = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
//            NSLog(@"HDURL: %@", APODdata[@"hdurl"]);


        }];

        // Begin task.
        [task resume];
        
        while (APODdata == nil){
            // do not leave initialization until data is fetched
        }
        
        hdurl = [NSString stringWithFormat:@"%@", APODdata[@"hdurl"]];
        pic = [[NSImage alloc] initByReferencingURL:[NSURL URLWithString:hdurl]];
        if (!pic.isValid){
            NSLog(@"image not created\n");
        }
        img_size = [pic size];
        img_height_by_width_ratio = img_size.height/img_size.width;
        
        desc = [NSString stringWithFormat:@"%@", APODdata[@"explanation"]];
        //desc = [NSString stringWithFormat:@"%@", APODdata[@"explanation"]];
        //desc = @"hello world, hello world";
        desc_length = [desc length];

       // scrollView = [[NSScrollView alloc]initWithFrame:frame];
        //[self addSubview:scrollView];


        
        NSRect picRect;
        NSSize picRectSize;
        if (img_height_by_width_ratio  > 1) { // height is bigger
            picRectSize = NSMakeSize(frame.size.height/img_height_by_width_ratio, frame.size.height);
            
            picRect = CGRectMake((frame.size.width-picRectSize.width)/2.0, 0, picRectSize.width, picRectSize.height);
        } else { // width is bigger
            picRectSize = NSMakeSize(frame.size.width, frame.size.width*img_height_by_width_ratio);
            picRect = CGRectMake(0, (frame.size.height-picRectSize.height)/2.0, picRectSize.width, picRectSize.height);
            //picRect = CGRectMake(0, 0, picRectSize.width, picRectSize.height);
        }
        NSView* maskView = [[NSView alloc]initWithFrame:picRect];
        [self addSubview:maskView];
        
        imageView = [[NSImageView alloc]initWithFrame:picRect];
        [imageView setImage:pic];
        [imageView setImageScaling:NSImageScaleProportionallyUpOrDown];
        imageViewOriginalSize = imageView.frame.size;
        [maskView addSubview:imageView];

        //CALayer *maskLayer = [CALayer layer];
        //maskLayer.bounds = picRectSize;
        
        //imageView.layer.mask = maskLayer;
        
        
        double character_width = font_fraction*frame.size.height*0.6; // estimate
        NSSize textSize = NSMakeSize(desc_length*character_width*1.1, (font_fraction + 0.01)*frame.size.height);
        textRect = NSMakeRect(0, frame.size.height-textSize.height,
                              textSize.width, textSize.height);
        
        NSUInteger num_horz_chars = frame.size.width/character_width;
        BOOL needs_padding = NO;
        NSRange string_range = NSMakeRange(string_start, num_horz_chars);
        if (desc_length < num_horz_chars){
            string_range = NSMakeRange(0, desc_length);
        } else if ((string_start + num_horz_chars) > desc_length){ // end of desc
            // do not exceed the length of desc
            string_range = NSMakeRange(string_start, desc_length - string_start);
            needs_padding = YES;
        } else if (string_start < num_horz_chars) { // start of desc
            string_range = NSMakeRange(0, string_start);
        }
        NSString* string_to_display = [desc substringWithRange:string_range];

        if (needs_padding) {
            string_to_display = [string_to_display stringByPaddingToLength:num_horz_chars withString:@" - " startingAtIndex:0];
        }

        font = [NSFont fontWithName:@"Monaco" size:font_fraction*frame.size.height];

        attributes = @{ NSFontAttributeName: font,
                        NSForegroundColorAttributeName: [NSColor lightGrayColor],
                        NSParagraphStyleAttributeName: paragraphStyle
        };

        // This method is also where the following NSRect variable gets size information. We need this information for this example.
        NSRect windowFrame = textRect;
        NSTextStorage *textStorage = [[NSTextStorage alloc] initWithString:desc];
        [textStorage setFont:font];
        [textStorage setForegroundColor:[NSColor lightGrayColor]];
        NSLayoutManager *manager = [[NSLayoutManager alloc] init];
        NSTextContainer *container = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(windowFrame.size.width, windowFrame.size.height)];
        textView = [[NSTextView alloc] initWithFrame:windowFrame textContainer:container];
        [textView setDefaultParagraphStyle:paragraphStyle];
        [textView setBackgroundColor:[NSColor colorWithSRGBRed:0 green:0 blue:0 alpha:0.6]];
        [textStorage addLayoutManager:manager];
        [manager addTextContainer:container];
        //[windowController.window setContentView:textView];
        [self addSubview:textView];


        startTime  = CACurrentMediaTime();
    }
    return self;
}

- (void)startAnimation
{
    [super startAnimation];
}

- (void)stopAnimation
{
    [super stopAnimation];
}

- (void)drawRect:(NSRect)rect
{
    NSLog(@"already in drawRect");
    
    // ----------- background -----------
    [super drawRect:rect];
    [[NSColor colorWithWhite:0.06 alpha:0.8] setFill];
    NSRectFill(rect);


    // ----------- picture -----------
    
    NSSize picRectSize;
    if (img_height_by_width_ratio  > 1) { // height is bigger
        picRectSize = NSMakeSize(rect.size.height/img_height_by_width_ratio, rect.size.height);
        
        picRect = CGRectMake((rect.size.width-picRectSize.width)/2.0, 0, picRectSize.width, picRectSize.height);
    } else { // width is bigger
        picRectSize = NSMakeSize(rect.size.width, rect.size.width*img_height_by_width_ratio);
        picRect = CGRectMake(0, (rect.size.height-picRectSize.height)/2.0, picRectSize.width, picRectSize.height);
        //picRect = CGRectMake(0, 0, picRectSize.width, picRectSize.height);
    }
    

    double portion_to_display = 1 - (zoom_fraq/1000.0);
    NSRect picPortionRect = { {img_size.width*(1-portion_to_display)*.5, img_size.height*(1-portion_to_display)*.5},
        {img_size.width*portion_to_display, img_size.height*portion_to_display}
    };

    // ----------- text -----------



    // ----------- drawing -----------
    
    //[super drawRect:picRect];
    //[super drawRect:textRect];
    //[pic drawInRect:picRect fromRect:picPortionRect operation:NSCompositingOperationCopy fraction:1];
    [[NSColor colorWithSRGBRed:0 green:0 blue:0 alpha:0.6] setFill];
    //NSRectFillUsingOperation(textRect, NSCompositingOperationSourceOver );
    //[string_to_display drawInRect:textRect withAttributes:attributes];

    
}

//- (double) lerp:(double) a secondNumber:(double) b time:(double) t
double lerp(double a, double b, double t)
{
    return a + (b - a) * t;
}

- (void)animateOneFrame
{
    // update values for animation:

    CFTimeInterval elapsedTime = CACurrentMediaTime() - startTime;
    
    zoom_fraq = zoom_fraq + update_zoom_by;
    
    // reverse zooming direction
    if ((zoom_fraq == 0) || (zoom_fraq == 300)){
        update_zoom_by = -update_zoom_by;
    }
    
    string_start = (string_start + 1) % desc_length;
    
    //double portion_to_display = 1/(1 - (zoom_fraq/100000.0));
    double portion_to_display = lerp(1, 1.2, (1 + sin((double)elapsedTime*.1))*.5);
    //[imageView scaleUnitSquareToSize:NSMakeSize(portion_to_display, portion_to_display)];
    //[imageView setBoundsSize:NSMakeSize(imageViewOriginalSize.width * portion_to_display, imageViewOriginalSize.height * //portion_to_display)];
    [imageView setFrame:NSMakeRect(0,0,imageViewOriginalSize.width * portion_to_display, imageViewOriginalSize.height * portion_to_display)];
    [imageView setNeedsDisplay:true];
    
    //NSRect newTextRect = textRect;
    //newTextRect.origin.x += lerp(0, -textView.frame.size.width, modf((double)elapsedTime, 10));
    //[textView setFrame:newTextRect];
    double scrollSeconds = desc_length*.1;
    [textView setFrame:NSMakeRect(textRect.origin.x - lerp(0, textRect.size.width, fmod(elapsedTime,scrollSeconds)/scrollSeconds), textRect.origin.y, textRect.size.width, textRect.size.height)];
    [textView setNeedsDisplay:true];

   // [scrollView setMagnification:portion_to_display];
    //[scrollView setNeedsDisplay:true];
    //[self setNeedsDisplayInRect:mainRect];
    return;
}

- (BOOL)hasConfigureSheet
{
    return NO;
}

- (NSWindow*)configureSheet
{
    return nil;
}

@end
