//
//  NSMutableAttributedString+LInk.m
//  TLAttributedLabel
//
//  Created by andezhou on 15/8/13.
//  Copyright (c) 2015年 andezhou. All rights reserved.
//

#import <CoreText/CoreText.h>
#import "NSMutableAttributedString+Link.h"
#import "NSMutableAttributedString+Config.h"
#import "NSMutableAttributedString+Picture.h"
#import "TLAttributedLabelConst.h"
#import "TLAttributedLink.h"
#import "TLAttributedImage.h"
#import <objc/runtime.h>

// 检查a标签/URL
static NSString *const pattern = @"(<a.*?[^<]+</a>)|((http[s]{0,1}|ftp)://[a-zA-Z0-9\\.\\-]+\\.([a-zA-Z]{2,4})(:\\d+)?(/[a-zA-Z0-9\\.\\-~!@#$%^&*+?:_/=<>]*)?)|(www.[a-zA-Z0-9\\.\\-]+\\.([a-zA-Z]{2,4})(:\\d+)?(/[a-zA-Z0-9\\.\\-~!@#$%^&*+?:_/=<>]*)?)|<img.*?>";

@implementation NSMutableAttributedString (Link)
static char imgAttStringKey;

- (NSMutableAttributedString *)imgAttString {
    return objc_getAssociatedObject(self, &imgAttStringKey);
}

- (void)setImgAttString:(NSMutableAttributedString *)imgAttString {
    objc_setAssociatedObject(self, &imgAttStringKey, imgAttString, OBJC_ASSOCIATION_COPY);
}

// 检查并处理链接
- (NSMutableArray *)setAttributedStringWithFont:(UIFont *)font
                                        showUrl:(BOOL)showUrl
                                      linkColor:(UIColor *)linkColor
                                         images:(NSMutableArray *)images {
    // 初始化用来保存链接的数组
    NSMutableArray *links = [NSMutableArray array];
    
    // 处理@、#、url和手机号码
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:nil];
    [regex enumerateMatchesInString:self.string options:0 range:NSMakeRange(0, self.string.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        
        NSString *txt = [self.string substringWithRange:result.range];
        TLAttributedLink *linkData = [[TLAttributedLink alloc] init];
        linkData.title = txt;
        linkData.url = txt;
        [links addObject:linkData];
    }];
    
    
    NSUInteger newlocation = 0;
    // 处理链接
    for (TLAttributedLink *linkData in links) {
        
        NSString *text = linkData.title;
        // 用于处理当title相同时的情况
        NSRange range = [self.string rangeOfString:text options:NSLiteralSearch range:NSMakeRange(newlocation, self.string.length - newlocation)];
        linkData.range = range;
        // 设置颜色和字体大小
        [self setFont:font range:linkData.range];
        [self setTextColor:linkColor range:linkData.range];
        
        if ([text hasPrefix:@"<a"]) {
            NSString *string = [self removeSignWithStr:text];
            NSArray *array = [string componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];
            for (int i = 0; i<array.count; i++) {
                NSString *str = array[i];
                if ([str isEqualToString:@"/a"]) {
                    if (showUrl)
                        linkData.title = text;
                    else
                        linkData.title = array[(i-1)>0?(i-1):0];
                    
                    NSString *url = array[(i-2)>0?(i-2):0];
                    NSRange range = [url rangeOfString:@"="];
                    linkData.url = [url substringFromIndex:range.location+1];
                    break;
                }
            }
            
            NSMutableAttributedString *urlAttString = [self addUrlAttStringWithLinkData:linkData font:font linkColor:linkColor images:images];
            [self replaceCharactersInRange:range withAttributedString:urlAttString];
            linkData.range = NSMakeRange(range.location + 1, urlAttString.length - 2);
        }else if([text hasPrefix:@"<img"]){
            NSString *string = [self removeSignWithStr:text];
            NSArray *array = [string componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"= >"]];
            for (int i= 0; i<array.count; i++) {
                if ([array[i] isEqualToString:@"src"]) {
                    NSString *str = array[(i+2)<array.count?(i+2):0];
                    linkData.url = str;
                    linkData.title = TLReplaceURLTitle;
                    break;
                }
            }
            NSMutableAttributedString *urlAttString = [self addImgAttStringWithLinkData:linkData font:font linkColor:linkColor images:images];
            [self replaceCharactersInRange:range withAttributedString:urlAttString];
            linkData.range = NSMakeRange(range.location + 1, urlAttString.length - 2);
        }
        
        newlocation = NSMaxRange(linkData.range);
    }
    
    return links;
}

// a标签
- (NSMutableAttributedString *)addUrlAttStringWithLinkData:(TLAttributedLink *)linkData font:(UIFont *)font linkColor:(UIColor *)linkColor images:(NSMutableArray *)images{
    // 设置图片属性
    TLAttributedImage *imageData = [[TLAttributedImage alloc] init];
    imageData.imageName = TLReplaceURLImageName;
    imageData.type = TLImagePNGTppe;
    imageData.imageSize = CGSizeMake(font.pointSize, font.pointSize);
    imageData.fontRef = CTFontCreateWithName((CFStringRef)font.fontName, font.pointSize, NULL);
    imageData.imageAlignment = TLImageAlignmentCenter;
    imageData.imageMargin = UIEdgeInsetsZero;
    [images addObject:imageData];
    
    // 创建图片带属性字符串
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:@" "];
    NSAttributedString *imageAttString = [self createImageAttributedString:imageData];
    [attributedString appendAttributedString:imageAttString];
    
    // 生成完成的链接
    NSMutableAttributedString *attString = [[NSMutableAttributedString alloc] initWithString:linkData.title];
    [attributedString appendAttributedString:attString];
    
    [attributedString appendAttributedString:[[NSAttributedString alloc]initWithString:@" "]];
    
    // 设置颜色和字体大小
    [attributedString setFont:font];
    [attributedString setTextColor:linkColor];
    
    return attributedString;
}
// img标签
- (NSMutableAttributedString *)addImgAttStringWithLinkData:(TLAttributedLink *)linkData font:(UIFont *)font linkColor:(UIColor *)linkColor images:(NSMutableArray *)images{
    if (!self.imgAttString) {
        self.imgAttString = [self addUrlAttStringWithLinkData:linkData font:font linkColor:linkColor images:images];
    }
    return self.imgAttString;
}

#pragma mark -
#pragma mark 添加自定义链接
static NSUInteger kLocation = 0;
- (NSArray *)setCustomLink:(NSString *)link
                      font:(UIFont *)font
                 linkColor:(UIColor *)color {
    kLocation = 0;
    // 检查可变字符串中的所有link
    NSMutableArray *customLinks = [NSMutableArray array];
    [self checkCustomLink:link string:self.string customLinks:customLinks];
    
    // 遍历所有满足条件的link，如果range跟link一致，着添加自定义链接
    for (TLAttributedLink *customLinkData in customLinks) {
        [self setFont:font range:customLinkData.range];
        [self setTextColor:color range:customLinkData.range];
    }
    
    return customLinks;
}

// 检查可变字符串中的所有link
- (void)checkCustomLink:(NSString *)link
                 string:(NSString *)string
            customLinks:(NSMutableArray *)customLinks {
    NSRange range = [string rangeOfString:link];
    
    if (range.location != NSNotFound) {
        TLAttributedLink *linkData = [[TLAttributedLink alloc] init];
        linkData.title = link;
        linkData.range = NSMakeRange(kLocation + range.location, range.length);
        [customLinks addObject:linkData];
        
        // 递归继续查询
        NSString *result = [string substringFromIndex:range.location + range.length];
        kLocation += range.location + range.length;
        [self checkCustomLink:link string:result customLinks:customLinks];
    }
}

- (NSString *)removeSignWithStr:(NSString *)str
{
    NSString *txt = [str copy];
    txt = [txt stringByReplacingOccurrencesOfString:@"\"" withString:@" "];
    txt = [txt stringByReplacingOccurrencesOfString:@"\'" withString:@" "];
    return txt;
}
@end
