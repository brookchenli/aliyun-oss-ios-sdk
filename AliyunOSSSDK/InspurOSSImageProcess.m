//
//  OSSImageProcess.m
//  InspurOSSSDK
//
//  Created by 陈历 on 2022/12/17.
//  Copyright © 2022 Inspur. All rights reserved.
//

#import "InspurOSSImageProcess.h"

#define InspurImageProcessStyle @"InspurImageProcessStyle"
#define InspurImageProcessRotato @"InspurImageProcessRotato"
#define InspurImageProcessFlip @"InspurImageProcessFlip"
#define InspurImageProcessFitResize @"InspurImageProcessFitResize"
#define InspurImageProcessResize @"InspurImageProcessResize"
#define InspurImageProcessMeta @"InspurImageProcessMeta"
#define InspurImageProcessBright @"InspurImageProcessBright"
#define InspurImageProcessContrast @"InspurImageProcessContrast"
#define InspurImageProcessSharpen @"InspurImageProcessSharpen"
#define InspurImageProcessWater @"InspurImageProcessWater"
#define InspurImageProcessBlindWater @"InspurImageProcessBlindWater"
#define InspurImageProcessDecodeBlindWater @"InspurImageProcessDecodeBlindWater"
#define InspurImageProcessInterlace @"InspurImageInterlace"
#define InspurImageProcessIndexcrop @"InspurImageIndexcrop"
#define InspurImageProcessCircle @"InspurImageCircle"
#define InspurImageProcessRoundedCorner @"InspurImageRoundedCorner"
#define InspurImageProcessFormat @"InspurImageProcessFormat"
#define InspurImageProcessQuality @"InspurImageProcessQuality"
#define InspurImageProcessAverageHue @"InspurImageAverageHue"
#define InspurImageProcessExif @"InspurImageExif"

#define InspurImageResizeModeKey @"InspurImageResizeModeKey"
#define InspurImageResizeWKey @"InspurImageResizeWKey"
#define InspurImageResizeHKey @"InspurImageResizeHKey"
#define InspurImageResizeSKey @"InspurImageResizeSKey"
#define InspurImageResizeLKey @"InspurImageResizeLKey"
#define InspurImageResizeLimitKey @"InspurImageResizeLimitKey"
#define InspurImageResizeColorKey @"InspurImageResizeColorKey"

#define InspurImageWaterMarkTextKey @"InspurImageWaterMarkTextKey"
#define InspurImageWaterMarkFontkey @"InspurImageWaterMarkFontkey"
#define InspurImageWaterMarkTextColorKey @"InspurImageWaterMarkTextColorKey"
#define InspurImageWaterMarkSizeKey @"InspurImageWaterMarkSizeKey"
#define InspurImageWaterMarkGKey @"InspurImageWaterMarkGKey"
#define InspurImageWaterMarkXKey @"InspurImageWaterMarkXKey"
#define InspurImageWaterMarkYKey @"InspurImageWaterMarkYKey"
#define InspurImageWaterMarkTKey @"InspurImageWaterMarkTKey"
#define InspurImageWaterMarkImageURLKey @"InspurImageWaterMarkImageURLKey"

#define InspurImageIndexcropValueKey @"InspurImageIndexcropValueKey"
#define InspurImageIndexcropIsXKey @"InspurImageIndexcropIsXKey"
#define InspurImageIndexcropIndexKey @"InspurImageIndexcropIndexKey"

@implementation NSString (InspurImageProcess)

-(NSString *)base64EncodeString {
    //1.先把字符串转换为二进制数据
    NSString *string = [self copy];
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    //2.对二进制数据进行base64编码，返回编码后的字符串
    return [data base64EncodedStringWithOptions:0];
}

- (NSString *)removeSentivie {
    NSString *string = [NSString stringWithFormat:@"%@", self];
    string = [string stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    string = [string stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    return string;
}

@end

@interface InspurImageWaterMarkOptionMode ()

@property (nonatomic, strong) NSString *paramsSting;

@end

@implementation InspurImageWaterMarkOptionMode : NSObject

//文字盲水印
- (instancetype)initWithBlindText:(NSString *)text{
    if (self = [super init]) {
        _paramsSting = [NSString stringWithFormat:@"type_encode,text_%@",[[text base64EncodeString] removeSentivie]];
    }
    return self;
}

//文字盲水印解码
- (instancetype)initWithBlindDecodeText:(NSString *)text{
    if (self = [super init]) {
        _paramsSting = [NSString stringWithFormat:@"type_textdecode,text_%@",[[text base64EncodeString] removeSentivie]];
    }
    return self;
}

//图片盲水印
- (instancetype)initWithBlindImage:(NSString *)imageURL {
    if (self = [super init]) {
        _paramsSting = [NSString stringWithFormat:@"type_encode,image_%@",[[imageURL base64EncodeString] removeSentivie]];
    }
    return self;
}

- (instancetype)initWithBlindDecodeImage {
    if (self = [super init]) {
        _paramsSting = [NSString stringWithFormat:@"type_imagedecode"];
    }
    return self;
}


- (instancetype)initWithText:(NSString *)text
                       color:(NSString *)color
                        font:(NSString *)font
                        size:(int)fontSize
                 transparent:(int)t
                    position:(NSString *)position
                     xMargin:(int)x
                     yMargin:(int)y {
    if (self = [super init]) {
        _paramsSting = [NSString stringWithFormat:@"text_%@,type_%@,color_%@,size_%@,g_%@,x_%d,y_%d,t_%d",[[text base64EncodeString] removeSentivie], [[font base64EncodeString] removeSentivie],color, @(fontSize), (position), (x), (y), (t)];
    }
    return self;
}

//图片水印
- (instancetype)initWithImage:(NSString *)imageUrl
                 transparent:(int)t
                    position:(NSString *)position
                     xMargin:(int)x
                      yMargin:(int)y {
    if (self = [super init]) {
        _paramsSting = [NSString stringWithFormat:@"g_%@,x_%d,y_%d,t_%d,image_%@", (position), (x), (y), (t), [[imageUrl base64EncodeString] removeSentivie]];
    }
    return self;
}

@end

@interface InspurImageAttributeMaker ()
@property (nonatomic, strong) NSMutableDictionary *params;
@end


@implementation InspurImageAttributeMaker

- (instancetype)init {
    if (self = [super init]) {
        _params = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)addAttribute:(NSString *)key value:(id)value {
    [self.params setObject:value forKey:key];
}

- (InspurImageAttributeMaker *(^)(NSString *styleName))style {
    return ^ InspurImageAttributeMaker *(NSString *styleName) {
        [self addAttribute:InspurImageProcessStyle value:styleName];
        return self;
    };
}

- (InspurImageAttributeMaker *(^)(int))rotato {
    return ^ InspurImageAttributeMaker *(int value) {
        [self addAttribute:InspurImageProcessRotato value:@(value)];
        return self;
    };
}

- (InspurImageAttributeMaker *(^)(InspurImageFlip flip))flip {
    return ^ InspurImageAttributeMaker *(InspurImageFlip flip) {
        [self addAttribute:InspurImageProcessFlip value:@(flip)];
        return self;
    };
}

- (InspurImageAttributeMaker *(^)(int resize))fitResize {
    return ^ InspurImageAttributeMaker *(int resize) {
        [self addAttribute:InspurImageProcessFitResize value:@(resize)];
        return self;
    };
}


- (InspurImageAttributeMaker *(^)(InspurImageResizeMode mode, NSNumber* _Nullable w, NSNumber* _Nullable h, NSNumber* _Nullable s, NSNumber* _Nullable l , NSNumber* _Nullable limit, NSString * _Nullable color))resize {
    return ^ InspurImageAttributeMaker *(InspurImageResizeMode mode, NSNumber* w, NSNumber* h, NSNumber* s, NSNumber* l , NSNumber* limit, NSString *color) {
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        [dictionary setValue:@(mode) forKey:InspurImageResizeModeKey];
        [dictionary setValue:w forKey:InspurImageResizeWKey];
        [dictionary setValue:h forKey:InspurImageResizeHKey];
        [dictionary setValue:s forKey:InspurImageResizeSKey];
        [dictionary setValue:l forKey:InspurImageResizeLKey];
        [dictionary setValue:limit forKey:InspurImageResizeLimitKey];
        [dictionary setValue:color forKey:InspurImageResizeColorKey];
        [self addAttribute:InspurImageProcessResize value:dictionary];
        return self;
    };
}


//TODO: 格式转换

- (InspurImageAttributeMaker *(^)(int bright))bright {
    return ^ InspurImageAttributeMaker *(int bright) {
        [self addAttribute:InspurImageProcessBright value:@(bright)];
        return self;
    };
}

- (InspurImageAttributeMaker *(^)(float contrast))contrast {
    return ^ InspurImageAttributeMaker *(float contrast) {
        [self addAttribute:InspurImageProcessContrast value:@(contrast)];
        return self;
    };
}

- (InspurImageAttributeMaker *(^)(float sharpen))sharpen {
    return ^ InspurImageAttributeMaker *(float sharpen) {
        [self addAttribute:InspurImageProcessSharpen value:@(sharpen)];
        return self;
    };
}

- (InspurImageAttributeMaker *(^)(NSArray <InspurImageWaterMarkOptionMode *> *waterMarks))watermark {
    return ^ InspurImageAttributeMaker *(NSArray <InspurImageWaterMarkOptionMode *> *waterMarks) {
        [self addAttribute:InspurImageProcessWater value:waterMarks];
        return self;
    };
}

- (InspurImageAttributeMaker *(^)(InspurImageWaterMarkOptionMode *waterMark))blindWatermark {
    return ^ InspurImageAttributeMaker *(InspurImageWaterMarkOptionMode *waterMark) {
        [self addAttribute:InspurImageProcessBlindWater value:waterMark];
        return self;
    };
}

- (InspurImageAttributeMaker *(^)(InspurImageWaterMarkOptionMode *waterMark))decodeBlindWatermark {
    return ^ InspurImageAttributeMaker *(InspurImageWaterMarkOptionMode *waterMark) {
        [self addAttribute:InspurImageProcessBlindWater value:waterMark];
        return self;
    };
}


- (InspurImageAttributeMaker *(^)(int interlace))interlace {
    return ^ InspurImageAttributeMaker *(int interlace) {
        [self addAttribute:InspurImageProcessInterlace value:@(interlace)];
        return self;
    };
}

- (InspurImageAttributeMaker *(^)(BOOL isX, int value, int index))indexcrop {
    return ^ InspurImageAttributeMaker *(BOOL isX, int value, int index) {
        [self addAttribute:InspurImageProcessIndexcrop value:@{
            InspurImageIndexcropValueKey:@(value),
            InspurImageIndexcropIsXKey:@(isX),
            InspurImageIndexcropIndexKey:@(index)
        }];
        return self;
    };
}

- (InspurImageAttributeMaker *(^)(int radius))circle {
    return ^ InspurImageAttributeMaker *(int radius) {
        [self addAttribute:InspurImageProcessCircle value:@(radius)];
        return self;
    };
}
- (InspurImageAttributeMaker *(^)(int radius))roundedCorners {
    return ^ InspurImageAttributeMaker *(int radius) {
        [self addAttribute:InspurImageProcessRoundedCorner value:@(radius)];
        return self;
    };
}

- (InspurImageAttributeMaker *(^)(NSString *))format {
    return ^ InspurImageAttributeMaker *(NSString *format) {
        [self addAttribute:InspurImageProcessFormat value:format];
        return self;
    };
}

- (InspurImageAttributeMaker *(^)(int quality))quality {
    return ^ InspurImageAttributeMaker *(int quality) {
        [self addAttribute:InspurImageProcessQuality value:@(quality)];
        return self;
    };
}


- (InspurImageAttributeMaker *(^)(void))averageHue {
    return ^ InspurImageAttributeMaker *(void) {
        [self addAttribute:InspurImageProcessAverageHue value:@(1)];
        return self;
    };
}

- (InspurImageAttributeMaker *(^)(void))info {
    return ^ InspurImageAttributeMaker *(void) {
        [self addAttribute:InspurImageProcessExif value:@(1)];
        return self;
    };
}

- (instancetype)rotato:(NSInteger)rotato {
    [self addAttribute:InspurImageProcessRotato value:@(rotato)];
    return self;
}

@end

@interface InspurOSSImageProcess ()

@property (nonatomic, strong) NSString *endPoint;
@property (nonatomic, strong) NSURLSession *session;

@end

@implementation InspurOSSImageProcess

- (instancetype)initWithEndPoint:(NSString *)endPoint {
    if (self = [super init]) {
        _endPoint = endPoint;
        [self initData];
    }
    return self;
}

- (void)initData {
    self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
}

- (NSString *)getURL:(NSString *)key
              bucket:(NSString *)bucket
             process:(InspurImageAttributeMakerBlock)block {
    InspurImageAttributeMaker *maker = [[InspurImageAttributeMaker alloc] init];
    block(maker);
    NSDictionary *params = [maker.params copy];
    if (params.count == 0) {
        return key;
    }
    NSString *newURL = [NSString stringWithFormat:@"%@/%@/%@?%@", self.endPoint, bucket, key, [self createUrlParamsWith:maker]];
    NSLog(@"newURL:%@", newURL);
    return newURL;
}


- (NSString *)createUrlParamsWith:(InspurImageAttributeMaker *)make {
    NSMutableArray *array = [NSMutableArray array];
    NSString *style = [make.params objectForKey:InspurImageProcessStyle];
    if (style.length > 0) {
        return [NSString stringWithFormat:@"x-oss-process=style/%@", style];
    }
    [self addRotato:make toArray:array];
    [self addFitresize:make toArray:array];
    [self addFlip:make toArray:array];
    [self addResize:make toArray:array];
    [self addBright:make toArray:array];
    [self addContrast:make toArray:array];
    [self addSharpen:make toArray:array];
    [self addFormat:make toArray:array];
    [self addQuality:make toArray:array];
    [self addWaterMark:make toArray:array];
    [self addBlindWaterMark:make toArray:array];
    [self addDecodeBlindWaterMark:make toArray:array];
    [self addInterlace:make toArray:array];
    [self addIndexcrop:make toArray:array];
    [self addCircle:make toArray:array];
    [self addRoundedCircle:make toArray:array];
    [self addAverageHue:make toArray:array];
    [self addExif:make toArray:array];
    return [NSString stringWithFormat:@"x-oss-process=image/%@", [array componentsJoinedByString:@"/"]];
}

- (void)addRotato:(InspurImageAttributeMaker *)make toArray:(NSMutableArray *)array {
    NSNumber *value = [make.params objectForKey:InspurImageProcessRotato];
    if (value && value.intValue >=0 && value.intValue <= 359) {
        [array addObject:[NSString stringWithFormat:@"rotate,%d", value.intValue]];
    }
}

- (void)addStyle:(InspurImageAttributeMaker *)make toArray:(NSMutableArray *)array {
    NSString *value = [make.params objectForKey:InspurImageProcessRotato];
    if (value && value.length > 0) {
        [array addObject:[NSString stringWithFormat:@"rotate,%d", value.intValue]];
    }
}

- (void)addFlip:(InspurImageAttributeMaker *)make toArray:(NSMutableArray *)array {
    NSNumber *value = [make.params objectForKey:InspurImageProcessFlip];
    if (value && value.intValue > 0 && value.intValue <= 2) {
        NSString *flip = (value.intValue == 1) ? @"horizontal" : @"vertical";
        [array addObject:[NSString stringWithFormat:@"flip,%@", flip]];
    }
}

- (void)addFitresize:(InspurImageAttributeMaker *)make toArray:(NSMutableArray *)array {
    NSNumber *value = [make.params objectForKey:InspurImageProcessFitResize];
    if (value && value.intValue >=1 && value.intValue <= 1000) {
        [array addObject:[NSString stringWithFormat:@"resize,p_%d", value.intValue]];
    }
}

- (void)addResize:(InspurImageAttributeMaker *)make toArray:(NSMutableArray *)array {
    NSDictionary *values = [make.params objectForKey:InspurImageProcessResize];
    if (values.count == 0) {
        return;
    }
    NSMutableArray *tmpArray = [NSMutableArray array];
    NSNumber *mode = [values objectForKey:InspurImageResizeModeKey];
    if (mode && mode.intValue > InspurImageResizeModeLfit && mode.intValue < InspurImageResizeModeFixed) {
        NSArray *list = @[@"", @"lfit", @"mfit", @"fill", @"pad", @"fixed"];
        [tmpArray addObject:[NSString stringWithFormat:@"m_%@", [list objectAtIndex:mode.intValue]]];
    }
    NSNumber *w = [values objectForKey:InspurImageResizeWKey];
    if (w) {
        [tmpArray addObject:[NSString stringWithFormat:@"w_%@", w]];
    }
    
    NSNumber *h = [values objectForKey:InspurImageResizeHKey];
    if (h) {
        [tmpArray addObject:[NSString stringWithFormat:@"h_%@", h]];
    }
    
    NSNumber *s = [values objectForKey:InspurImageResizeSKey];
    if (s) {
        [tmpArray addObject:[NSString stringWithFormat:@"s_%@", s]];
    }
    
    NSNumber *l = [values objectForKey:InspurImageResizeLKey];
    if (l) {
        [tmpArray addObject:[NSString stringWithFormat:@"l_%@", l]];
    }
    
    NSNumber *limit = [values objectForKey:InspurImageResizeLimitKey];
    if (limit) {
        [tmpArray addObject:[NSString stringWithFormat:@"limit_%@", limit]];
    }
    
    NSString *color = [values objectForKey:InspurImageResizeColorKey];
    if (color) {
        [tmpArray addObject:[NSString stringWithFormat:@"color_%@", color]];
    }
    if (tmpArray.count > 0) {
        [array addObject:[NSString stringWithFormat:@"resize,%@", [tmpArray componentsJoinedByString:@","]]];
    }
}

- (void)addBright:(InspurImageAttributeMaker *)make toArray:(NSMutableArray *)array {
    NSNumber *value = [make.params objectForKey:InspurImageProcessBright];
    if (value && value.intValue >= -100 && value.intValue <= 100) {
        [array addObject:[NSString stringWithFormat:@"bright,%d", value.intValue]];
    }
}

- (void)addContrast:(InspurImageAttributeMaker *)make toArray:(NSMutableArray *)array {
    NSNumber *value = [make.params objectForKey:InspurImageProcessContrast];
    if (value && value.intValue >= -100 && value.intValue <= 100) {
        [array addObject:[NSString stringWithFormat:@"contrast,%d", value.intValue]];
    }
}

- (void)addSharpen:(InspurImageAttributeMaker *)make toArray:(NSMutableArray *)array {
    NSNumber *value = [make.params objectForKey:InspurImageProcessSharpen];
    if (value && value.intValue >= 50 && value.intValue <= 399) {
        [array addObject:[NSString stringWithFormat:@"sharpen,%d", value.intValue]];
    }
}

- (void)addFormat:(InspurImageAttributeMaker *)make toArray:(NSMutableArray *)array {
    NSString *format = [make.params objectForKey:InspurImageProcessFormat];
    if (format && format.length > 0) {
        [array addObject:[NSString stringWithFormat:@"format,%@", format]];
    }
}

- (void)addQuality:(InspurImageAttributeMaker *)make toArray:(NSMutableArray *)array {
    NSNumber *value = [make.params objectForKey:InspurImageProcessQuality];
    if (value) {
        [array addObject:[NSString stringWithFormat:@"quality,%d", value.intValue]];
    }
}

- (void)addWaterMark:(InspurImageAttributeMaker *)make toArray:(NSMutableArray *)array {
    NSArray <InspurImageWaterMarkOptionMode *> *list = [make.params objectForKey:InspurImageProcessWater];
    if (list.count == 0) {
        return;
    }
    for (InspurImageWaterMarkOptionMode *param in list) {
        [array addObject:[NSString stringWithFormat:@"watermark,%@", param.paramsSting]];
    }
}

- (void)addBlindWaterMark:(InspurImageAttributeMaker *)make toArray:(NSMutableArray *)array {
    InspurImageWaterMarkOptionMode *blind = [make.params objectForKey:InspurImageProcessBlindWater];
    if (!blind) {
        return;
    }
    [array addObject:[NSString stringWithFormat:@"blind-watermark,%@", blind.paramsSting]];
}

- (void)addDecodeBlindWaterMark:(InspurImageAttributeMaker *)make toArray:(NSMutableArray *)array {
    InspurImageWaterMarkOptionMode *blind = [make.params objectForKey:InspurImageProcessDecodeBlindWater];
    if (!blind) {
        return;
    }
    [array addObject:[NSString stringWithFormat:@"blind-watermark,%@", blind.paramsSting]];
}

- (void)addInterlace:(InspurImageAttributeMaker *)make toArray:(NSMutableArray *)array {
    NSNumber *value = [make.params objectForKey:InspurImageProcessInterlace];
    if (value) {
        [array addObject:[NSString stringWithFormat:@"interlace,%d", value.intValue]];
    }
}

- (void)addIndexcrop:(InspurImageAttributeMaker *)make toArray:(NSMutableArray *)array {
    NSDictionary *values = [make.params objectForKey:InspurImageProcessIndexcrop];
    NSNumber *isX = [values objectForKey:InspurImageIndexcropIsXKey];
    NSNumber *value = [values objectForKey:InspurImageIndexcropValueKey];
    NSNumber *index = [values objectForKey:InspurImageIndexcropIndexKey];
    if (!isX || !value || !index) {
        return;
    }
    
    [array addObject:[NSString stringWithFormat:@"indexcrop,%@_%@,i_%@", isX ? @"x" : @"y", value, index]];
}

- (void)addCircle:(InspurImageAttributeMaker *)make toArray:(NSMutableArray *)array {
    NSNumber *value = [make.params objectForKey:InspurImageProcessCircle];
    if (value) {
        [array addObject:[NSString stringWithFormat:@"circle,r_%d", value.intValue]];
    }
}

- (void)addRoundedCircle:(InspurImageAttributeMaker *)make toArray:(NSMutableArray *)array {
    NSNumber *value = [make.params objectForKey:InspurImageProcessRoundedCorner];
    if (value) {
        [array addObject:[NSString stringWithFormat:@"rounded-corners,r_%d", value.intValue]];
    }
}

- (void)addAverageHue:(InspurImageAttributeMaker *)make toArray:(NSMutableArray *)array {
    NSNumber *value = [make.params objectForKey:InspurImageProcessAverageHue];
    if (value && value.intValue == 1) {
        [array addObject:[NSString stringWithFormat:@"average-hue"]];
    }
}

- (void)addExif:(InspurImageAttributeMaker *)make toArray:(NSMutableArray *)array {
    NSNumber *value = [make.params objectForKey:InspurImageProcessExif];
    if (value && value.intValue == 1) {
        [array addObject:[NSString stringWithFormat:@"info"]];
    }
}

- (void)averageHue:(NSString *)key
            bucket:(NSString *)bucket
        completion: (InspurImageInfoCompletion)completion {
    
    NSString *url = [NSString stringWithFormat:@"%@/%@/%@?%@", self.endPoint, bucket, key, @"x-oss-process=average-hue"];
    [self fetchInfo:url completion:completion];
}


- (void)exifInfo:(NSString *)key
          bucket:(NSString *)bucket
      completion:(InspurImageInfoCompletion)completion {
    NSString *url =  [NSString stringWithFormat:@"%@/%@/%@?%@", self.endPoint, bucket, key, @"x-oss-process=info"];
    [self fetchInfo:url completion:completion];
}

- (void)fetchInfo:(NSString *)url completion:(InspurImageInfoCompletion)completion {
    NSURLSessionTask *task = [self.session dataTaskWithURL:[NSURL URLWithString:url] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error && completion) {
            completion(nil, error);
        } else {
            NSError *error1;
            NSMutableDictionary * innerJson = [NSJSONSerialization JSONObjectWithData:data
                                                          options:kNilOptions
                                                            error:&error1];
            if (error) {
                completion(nil, error);
            } else {
                completion(innerJson, nil);
            }
            NSLog(@"innerJson:%@ error:%@", innerJson, error);
        }
    }];
    [task resume];
}


@end
