//
//  OSSImageProcess.h
//  AliyunOSSSDK
//
//  Created by 陈历 on 2022/12/17.
//  Copyright © 2022 aliyun. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class InspurImageAttribute;
@class InspurImageAttributeMaker;

#define InspurImageWaterMarkPositionTL @"tl"
#define InspurImageWaterMarkPositionTop @"top"
#define InspurImageWaterMarkPositionTR @"tr"
#define InspurImageWaterMarkPositionLeft @"left"
#define InspurImageWaterMarkPositionCenter @"center"
#define InspurImageWaterMarkPositionRight @"right"
#define InspurImageWaterMarkPositionBL @"bl"
#define InspurImageWaterMarkPositionBottom @"bottom"
#define InspurImageWaterMarkPositionBR @"br"

#define InspurImageWaterMarkFontSiyuanSongti @"思源宋体"
#define InspurImageWaterMarkFontSiyuanHeiti @"思源黑体"
#define InspurImageWaterMarkFontWequan @"文泉微米黑"

typedef void (^InspurImageAttributeMakerBlock)(InspurImageAttributeMaker *maker);
typedef void (^InspurImageInfoCompletion)(id _Nullable obj, NSError * _Nullable error);

typedef NS_ENUM(NSUInteger, InspurImageFlip) {
    InspurImageFlipNone,
    InspurImageFlipHorizontal, //水平方向
    InspurImageFlipVertical //垂直方向
};

typedef NS_ENUM(NSUInteger, InspurImageResizeMode) {
    InspurImageResizeModeNone,
    InspurImageResizeModeLfit,
    InspurImageResizeModeMfit,
    InspurImageResizeModeFill,
    InspurImageResizeModePad,
    InspurImageResizeModeFixed
};

@interface InspurImageWaterMarkOptionMode : NSObject

@property (nonatomic, strong, readonly) NSString *paramsSting;

//文字盲水印
- (instancetype)initWithBlindText:(NSString *)text;
- (instancetype)initWithBlindDecodeText:(NSString *)text;

//图片盲水印
- (instancetype)initWithBlindImage:(NSString *)imageURL;
- (instancetype)initWithBlindDecodeImage;

/*
- (instancetype)initWithDecodeBlindText:(NSString *)text;
- (instancetype)initWithBlindImage:(NSString *)imageURL;
*/

//文字水印
- (instancetype)initWithText:(NSString *)text
                       color:(NSString *)color
                        font:(NSString *)font
                        size:(int)fontSize
                 transparent:(int)t
                    position:(NSString *)position
                     xMargin:(int)x
                     yMargin:(int)y;

//图片水印
- (instancetype)initWithImage:(NSString *)imageUrl
                 transparent:(int)t
                    position:(NSString *)position
                     xMargin:(int)x
                     yMargin:(int)y;

- (NSString *)toString;

@end

@interface InspurImageAttributeMaker : NSObject
/**
 *    选择模版
 *
 *    styleName              模版名称
 */
- (InspurImageAttributeMaker *(^)(NSString *styleName))style;
/**
 *    图片旋转
 *
 *    rotato              旋转角度, 取值范围: (0 - 359)
 *
 */
- (InspurImageAttributeMaker *(^)(int angle))rotato;
/**
 *    图片翻转
 *
 *    flip                   翻转方向,水平或垂直
 */
- (InspurImageAttributeMaker *(^)(InspurImageFlip flip))flip;
/**
 *         等比缩放
 *
 *    resize                  与原图的比例为整数类型，取值为1到1000，小于100为缩小，大于100为放大
 */
- (InspurImageAttributeMaker *(^)(int resize))fitResize;
/**
 *         图片指定宽高缩放
 *
 *    mode 5中模式
 *（1）lfit：等比缩放，限制在指定长宽的矩形内的最大图片。
 *（2）mfit：等比缩放，延伸出指定长宽的矩形外的最小图片。
 *（3）fill：固定宽高，将mfit得到的图片进行居中裁剪。
 *（4）pad：固定宽高，将lfit得到的图片置于指定宽高的矩形正中，然后将空白处进行填充。
 *（5）fixed：    强制缩放到指定宽高。
 *    w     指定宽度,
 *    h     指定高度
 *    s     指定短边
 *    l      指定长边
 *    limit 是否限制放大
 *    color     pad模式时，需要添加一个填充颜色的参数
 */
- (InspurImageAttributeMaker *(^)(InspurImageResizeMode mode,
                                  NSNumber* _Nullable w,
                                  NSNumber* _Nullable h,
                                  NSNumber* _Nullable s,
                                  NSNumber* _Nullable l ,
                                  NSNumber* _Nullable limit,
                                  NSString * _Nullable color))resize;
/**
 *         亮度调节
 *
 *    bright                 调节程度为整数类型，取值为-100到100，小于0为调暗，大于0为调亮
 */
- (InspurImageAttributeMaker *(^)(int bright))bright;
/**
 *         对比度调节
 *
 *    contrast                 调节程度为整数类型，取值为-100到100，小于0为降低对比度，大于0为增加对比度
 */
- (InspurImageAttributeMaker *(^)(float contrast))contrast;
/**
 *         图片锐化
 *
 *    sharpen                 锐化程度为整数类型，取值为50到399
 */
- (InspurImageAttributeMaker *(^)(float sharpen))sharpen;

/**
 *         水印
 *
 *    waterMarks  水印模型数组
 */
- (InspurImageAttributeMaker *(^)(NSArray <InspurImageWaterMarkOptionMode *> *waterMarks))watermark;
/**
 *         盲水印
 *
 *    waterMark  水印模型数组
 */
- (InspurImageAttributeMaker *(^)(InspurImageWaterMarkOptionMode *waterMark))blindWatermark;
/**
 *         盲水印解码
 *
 *    waterMark  水印模型数组
 */
- (InspurImageAttributeMaker *(^)(InspurImageWaterMarkOptionMode *waterMark))decodeBlindWatermark;
/**
 *         渐进显示
 *
 *    interlace  参数取值0、1，1表示将原图设置成渐进显示，0表示将原图设置成标准显示
 */
- (InspurImageAttributeMaker *(^)(int interlace))interlace;
/**
 *         索引剪切
 *    在x(y)轴剪切出的每块区域的长度,i_选择剪切后返回的图片区域
 *    isX   在X轴方向处理,否则y轴
 *    value 指定区域的长度
 *    index 选取的索引
 */
- (InspurImageAttributeMaker *(^)(BOOL isX, int value, int index))indexcrop;
/**
 *         内切圆裁剪
 *
 *    radius  当取值大于原图最小边的一半时，以原图最小边的一半为值返回内切圆
 */
- (InspurImageAttributeMaker *(^)(int radius))circle;
/**
 *         圆角矩形裁剪
 *
 *    radius  如果指定圆角的半径大于原图最大内切圆的半径，则按照图片最大内切圆的半径设置圆角。
 */
- (InspurImageAttributeMaker *(^)(int radius))roundedCorners;
/**
 *         格式转换
 *
 *    format                  格式转换支持jpg、jpeg、png、bmp、gif、tiff之间的互相转换
 */
- (InspurImageAttributeMaker *(^)(NSString *format))format;
/**
 *         图片质量压缩
 *
 *    quality
 */
- (InspurImageAttributeMaker *(^)(int quality))quality;
/**
 *         获取图片主色调
 *
 */
- (InspurImageAttributeMaker *(^)(void))averageHue;
/**
 *         获取图片信息
 *
 */
- (InspurImageAttributeMaker *(^)(void))info;

@end

@interface InspurOSSImageProcess : NSObject

- (instancetype)initWithEndPoint:(NSString *)endPoint;

- (NSString *)getURL:(NSString *)key
              bucket:(NSString *)bucket
             process:(InspurImageAttributeMakerBlock)block;

- (void)averageHue:(NSString *)key
            bucket:(NSString *)bucket
        completion: (InspurImageInfoCompletion)completion;

- (void)exifInfo:(NSString *)key
          bucket:(NSString *)bucket
      completion:(InspurImageInfoCompletion)completion;

@end

NS_ASSUME_NONNULL_END
