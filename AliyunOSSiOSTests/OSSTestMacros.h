//
//  OSSTestMacros.h
//  InspurOSSiOSTests
//
//  Created by xx on 2017/12/11.
//  Copyright © 2022年 Inspur. All rights reserved.
//

#ifndef OSSTestMacros_h
#define OSSTestMacros_h

//#define OSS_ACCESSKEY_ID                @"AccessKeyID"                              // 子账号id
//#define OSS_SECRETKEY_ID                @"AccessKeySecret"                          // 子账号secret

#if 0 //native
#define OSS_ACCESSKEY_ID                @"inspur-a7f729b0-8615-4d48-9985-c92a795bc880-oss"                              // 子账号id
#define OSS_SECRETKEY_ID                @"FlzDEO25QsVxI3hcQntciclDYKxAa4aB6zRveqZ6"                          // 子账号secret
#elif 0 //共有云
#define OSS_ACCESSKEY_ID                @"ZjQxNjgzMDQtYmY0ZC00MjdlLTg0MTctNThlZGE2OGYxNjU3"                              // 子账号id
#define OSS_SECRETKEY_ID                @"NzAyMWM1ZDAtYTZjNC00ZmNhLTlhYTAtMmNjMDNhMmNmNTFl"                          // 子账号secret
#else
#define OSS_ACCESSKEY_ID                @"NTNiYWY3YWUtNTg0MS00MThmLThmZmUtMzE3ODUwMGM1YTg2"                              // 子账号id
#define OSS_SECRETKEY_ID                @"MTVjY2RlZDktMDc5OC00ZWFkLWI0YjEtM2M2MjJmODUyOTI3"                          // 子账号secret
#endif

//#define OSS_BUCKET_PUBLIC               @"public-bucket"                            // bucket名称
//#define OSS_BUCKET_PRIVATE              @"private-bucket"                           // bucket名称
//#define OSS_ENDPOINT                    @"http://oss-cn-region.aliyuncs.com"      // 访问的阿里云endpoint

#define OSS_BUCKET_PUBLIC               @"test"                            // bucket名称
#define OSS_BUCKET_PRIVATE              @"test"                           // bucket名称
#if 0
#define OSS_ENDPOINT                    @"http://10.110.62.51:8088"      // 访问的阿里云endpoint
#elif 0 //共有云
#define OSS_ENDPOINT                    @"https://cn-north-3.inspurcloudoss.com"
#else
#define OSS_ENDPOINT                    @"http://10.110.64.152:8088"

#endif

#define OSS_IMG_ENDPOINT                @"http://img-cn-region.aliyuncs.com"      // 旧版本图片服务的endpoint
#define OSS_MULTIPART_UPLOADKEY         @"multipart_key"                            // 分片上传的object key
#define OSS_RESUMABLE_UPLOADKEY         @"resumable_key"                            // 断点续传的object key
#define OSS_CALLBACK_URL                @"http://oss-demo.aliyuncs.com:23450"       // 对象上传成功时回调的业务服务器地址
#define OSS_CNAME_URL                   @"http://www.cnametest.com/"                // cname，用于替换bucket.endpoint的访问域名
#define OSS_STSTOKEN_URL                @"http://*.*.*.*:****/sts/getsts"           // sts授权服务器的地址
#define OSS_IMAGE_KEY                   @"testImage.png"                            // 测试图片的名称

#define OSS_DOWNLOAD_FILE_NAME          @"OSS_DOWNLOAD_FILE_NAME"                   // 用于下载的object key

#endif /* OSSTestMacros_h */
