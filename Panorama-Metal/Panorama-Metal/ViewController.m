//
//  ViewController.m
//  LearnMetal
//
//  Created by user on 23/8/18.
//  Copyright © 2018年 Fanfan. All rights reserved.
//

#import "ViewController.h"
#import <Metal/Metal.h>
#import <GLKit/GLKit.h>
#import "LYShaderTypes.h"
#import "Bridging-Header.h"

#define kAcceleration 8
#define kPlanetMaxDegree 145

typedef NS_ENUM(NSUInteger, DFPanoramaModel){
    DFPanoramaModelNoramal,
    DFPanoramaModelLitlePlanet,
    DFPanoramaModelFisheye,
};


@interface ViewController ()<MTKViewDelegate>
@property (nonatomic, strong) MTKView *mtkView;

@property (nonatomic, assign) vector_uint2 viewportSize;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLTexture> texture;
@property (nonatomic, strong) id<MTLBuffer> vertices;
@property (nonatomic, strong) id<MTLBuffer> textures;
@property (nonatomic, strong) id<MTLBuffer> indices;

@property (nonatomic, assign) NSUInteger numIndices;

@property (nonatomic, assign) DFPanoramaModel type;     //控制模式
@property (nonatomic, assign) GLKMatrix4 orginEyeMatrix;
@property (nonatomic, assign) float mvpDegree;          //控制缩放
@property (nonatomic, assign) float horizontalDegree;   //控制水平方向
@property (nonatomic, assign) float verticalDegree;     //控制垂直方向

//滑动效果
@property (nonatomic, assign) float horizontalSpeed;
@property (nonatomic, assign) float verticalSpeed;
@property (nonatomic, assign) BOOL smoothEffect;
@property (nonatomic, assign) BOOL scaleEffect;
@property (nonatomic, assign) float acceleration;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.mtkView = [[MTKView alloc] initWithFrame:self.view.bounds];
    self.mtkView.device = MTLCreateSystemDefaultDevice();
    self.view = self.mtkView;
    self.mtkView.delegate = self;
    self.viewportSize = (vector_uint2){self.mtkView.drawableSize.width, self.mtkView.drawableSize.height};
//    self.mtkView.transform = CGAffineTransformMakeRotation(M_PI);

    
    [self customInit];
    
    [self addPanGestureRecognizer];
    
    UIButton *modelBtn = [[UIButton alloc] initWithFrame:CGRectMake(20, 50, 100, 50)];
    [modelBtn setTitle:@"普通" forState:UIControlStateNormal];
    modelBtn.titleLabel.font = [UIFont systemFontOfSize:16.0f];
    [modelBtn setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [modelBtn addTarget:self action:@selector(clickBtn:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:modelBtn];
}



- (void)setupMatrixWithEncoder:(id<MTLRenderCommandEncoder>)renderEncoder {
    [self smooth];
    [self scaleToMaxOrdMin];
    
    GLKMatrix4 mvpMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(self.mvpDegree), CGRectGetWidth(self.view.bounds) / CGRectGetHeight(self.view.bounds), 0.1, 10);
    
    GLKMatrix4 lookAtMatrix = GLKMatrix4RotateX(self.orginEyeMatrix, _verticalDegree);
    
    GLKMatrix4 rotateX = GLKMatrix4RotateY(GLKMatrix4Identity, _horizontalDegree);
    
    LYMatrix matrix = {[self getMetalMatrixFromGLKMatrix:mvpMatrix], [self getMetalMatrixFromGLKMatrix:lookAtMatrix], [self getMetalMatrixFromGLKMatrix:rotateX]};
    
    [renderEncoder setVertexBytes:&matrix
                           length:sizeof(matrix)
                          atIndex:2];
}

/**
 找了很多文档，都没有发现metalKit或者simd相关的接口可以快捷创建矩阵的，于是只能从GLKit里面借力
 
 @param matrix GLKit的矩阵
 @return metal用的矩阵
 */
- (matrix_float4x4)getMetalMatrixFromGLKMatrix:(GLKMatrix4)matrix {
    matrix_float4x4 ret = (matrix_float4x4){
        simd_make_float4(matrix.m00, matrix.m01, matrix.m02, matrix.m03),
        simd_make_float4(matrix.m10, matrix.m11, matrix.m12, matrix.m13),
        simd_make_float4(matrix.m20, matrix.m21, matrix.m22, matrix.m23),
        simd_make_float4(matrix.m30, matrix.m31, matrix.m32, matrix.m33),
    };
    return ret;
}

- (void)customInit {
    [self setupPipeline];
    [self setupVertex];
    [self setupTexture];
}


/// 设置渲染管道
- (void)setupPipeline {
    id<MTLLibrary> defaultLibrary = [self.mtkView.device newDefaultLibrary];
    id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
    id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"samplingShader"];
    
    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.vertexFunction = vertexFunction;
    pipelineStateDescriptor.fragmentFunction = fragmentFunction;
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = self.mtkView.colorPixelFormat;
    self.pipelineState = [self.mtkView.device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:nil];
    self.commandQueue = [self.mtkView.device newCommandQueue];
}

/// 设置顶点数据
- (void)setupVertex {
    float *vertices = 0;// 顶点
    float *texCoord = 0;// 纹理
    uint16_t *indices  = 0;// 索引
    int numVertices = 0;
    self.numIndices = initSphere(200, 1.0f, 360, &vertices, &texCoord, &indices, &numVertices);
    
    self.vertices = [self.mtkView.device newBufferWithBytes:vertices
                                                     length:sizeof(float) * 4 * numVertices
                                                    options:MTLResourceStorageModeShared]; // 创建顶点缓存
    self.textures = [self.mtkView.device newBufferWithBytes:texCoord
                                                     length:sizeof(float) * 2 * numVertices
                                                    options:MTLResourceStorageModeShared]; // 创建纹理坐标缓存
    self.indices = [self.mtkView.device newBufferWithBytes:indices
                                                     length:sizeof(uint16_t) * self.numIndices
                                                    options:MTLResourceStorageModeShared];  //索引缓存
}

/// 设置纹理
- (void)setupTexture {
    UIImage *image = [UIImage imageNamed:@"sence.jpg"];
    
    MTLTextureDescriptor *textureDescriptor = [[MTLTextureDescriptor alloc] init];
    textureDescriptor.pixelFormat = MTLPixelFormatRGBA8Unorm;
    textureDescriptor.width = image.size.width;
    textureDescriptor.height = image.size.height;
    self.texture = [self.mtkView.device newTextureWithDescriptor:textureDescriptor];
    
    MTLRegion region = {{0, 0, 0}, {image.size.width, image.size.height, 1}};
    Byte *imageBytes = [self loadImage:image];
    if (imageBytes) {
        [self.texture replaceRegion:region mipmapLevel:0 withBytes:imageBytes bytesPerRow:4 * image.size.width];
        free(imageBytes);
        imageBytes = NULL;
    }
    
}

- (Byte *)loadImage:(UIImage *)image {
    CGImageRef spriteImage = image.CGImage;
    
    size_t width = CGImageGetWidth(spriteImage);
    size_t height = CGImageGetHeight(spriteImage);
    
    Byte *spriteData = (Byte *)calloc(width * height * 4, sizeof(Byte));
    
    CGContextRef spriteContext = CGBitmapContextCreate(spriteData, width, height, 8, width * 4, CGImageGetColorSpace(spriteImage), kCGImageAlphaPremultipliedLast);
    
    CGContextDrawImage(spriteContext, CGRectMake(0, 0, width, height), spriteImage);
    
    CGContextRelease(spriteContext);
    return spriteData;
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    self.viewportSize = (vector_uint2){size.width, size.height};
}

- (void)drawInMTKView:(nonnull MTKView *)view {
    
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    if(renderPassDescriptor != nil)
    {
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0f); // 设置默认颜色
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor]; //编码绘制指令的Encoder
        [renderEncoder setViewport:(MTLViewport){0.0, 0.0, self.viewportSize.x, self.viewportSize.y, -1.0, 1.0 }]; // 设置显示区域
        [renderEncoder setRenderPipelineState:self.pipelineState]; // 设置渲染管道，以保证顶点和片元两个shader会被调用
        
        [renderEncoder setFrontFacingWinding:MTLWindingClockwise];
        [renderEncoder setCullMode:MTLCullModeBack];
        
        [self setupMatrixWithEncoder:renderEncoder];
        
        [renderEncoder setVertexBuffer:self.vertices
                                offset:0
                               atIndex:0]; // 设置顶点缓存
        
        [renderEncoder setVertexBuffer:self.textures
                                offset:0
                               atIndex:1]; // 设置顶点缓存
        
        [renderEncoder setFragmentTexture:self.texture
                                  atIndex:0]; // 设置纹理
        
    
        [renderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                                  indexCount:self.numIndices
                                   indexType:MTLIndexTypeUInt16
                                 indexBuffer:self.indices
                           indexBufferOffset:0];
        
        [renderEncoder endEncoding]; // 结束
        
        [commandBuffer presentDrawable:view.currentDrawable]; // 显示
    }
    
    [commandBuffer commit]; // 提交；
}


///设置观看模式
- (void)setPanoramicModel:(DFPanoramaModel)type {
    self.type = type;
    self.mvpDegree = 90;
    switch (type) {
        case DFPanoramaModelNoramal:
        {
            self.orginEyeMatrix = GLKMatrix4MakeLookAt(0, 0, 0,
                                                       0, 0, -1.0f,
                                                       0, -1.0f, 0);
        }
            break;
        case DFPanoramaModelLitlePlanet:
        {
            self.mvpDegree = kPlanetMaxDegree;
            self.orginEyeMatrix = GLKMatrix4MakeLookAt(0, 0, 1.0f,
                                                       0, 0, -1.0f,
                                                       0, -1.0f, 0);
        }
            break;
        case DFPanoramaModelFisheye:
        {
            self.orginEyeMatrix = GLKMatrix4MakeLookAt(0, 0, 2.0f,
                                                       0, 0, -1.0f,
                                                       0, -1.0f, 0);
        }
            break;
            
        default:
            break;
    }
    
    self.horizontalDegree = 0;
    self.verticalDegree = 0;
    
}


#pragma mark ============ 手势控制
- (void)addPanGestureRecognizer {
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panActionDidClick:)];
    [self.view addGestureRecognizer:pan];
    
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchActionDidClick:)];
    [self.view addGestureRecognizer:pinch];
    
    
    [self setPanoramicModel:DFPanoramaModelNoramal];
}

- (void)panActionDidClick:(UIPanGestureRecognizer *)ges {
    CGPoint point = [ges translationInView:ges.view];
    [ges setTranslation:CGPointZero inView:ges.view];
    
    _verticalDegree += point.y / 100;
    _horizontalDegree += point.x / 100;
    
    [self setVerticalMaxAndMin];
    
    if (ges.state == UIGestureRecognizerStateEnded) {
        self.smoothEffect = YES;
        CGPoint velocity = [ges velocityInView:self.view];
        self.acceleration = kAcceleration;
        self.horizontalSpeed = velocity.x / 10;
        self.verticalSpeed = velocity.y / 10;
    } else {
        self.smoothEffect = NO;
        self.horizontalSpeed = 0;
        self.verticalSpeed = 0;
    }
    
}

- (void)pinchActionDidClick:(UIPinchGestureRecognizer *)ges {
    
    float baseDegree = 90;
    baseDegree *= (1 - ges.scale);
    baseDegree = [self scaleSpaceWithDegree:baseDegree];
    self.mvpDegree += baseDegree;
    ges.scale = 1;
    
    if (ges.state == UIGestureRecognizerStateEnded) {
        self.scaleEffect = YES;
    } else {
        self.scaleEffect = NO;
    }
    
}

- (void)smooth {
    if (!self.smoothEffect) {
        return;
    }
    float horizontalValue = self.horizontalSpeed / 1000;
    float verticalValue = self.verticalSpeed / 1000;
    self.horizontalDegree += horizontalValue;
    self.verticalDegree += verticalValue;
    self.horizontalSpeed = [self smoothSpace:self.horizontalSpeed];
    self.verticalSpeed = [self smoothSpace:self.verticalSpeed];
    if (self.horizontalSpeed == 0 && self.verticalSpeed == 0) {
        self.smoothEffect = NO;
    }
    
    [self setVerticalMaxAndMin];
}

- (float)smoothSpace:(float)speed {
    
    if (speed == 0) {
        return 0;
    }
    if (self.acceleration > 1) {
        self.acceleration -= 0.05;
    }
    int a = self.acceleration;
    if (speed > 0) {
        a = -self.acceleration;
    }
    speed += a;
    if ((speed > 0 && a > 0) || (speed < 0 && a < 0)) {
        speed = 0;
    }
    return speed;
}

//设置vertical的最大和最小角度
- (void)setVerticalMaxAndMin {
    double minDegree = -M_PI_2;
    double maxDegree = M_PI_2;
    
    if (_verticalDegree > maxDegree) {
        _verticalDegree = maxDegree;
    }else if (_verticalDegree < minDegree){
        _verticalDegree = minDegree;
    }
}

- (float)scaleSpaceWithDegree:(float)degree {
    float minDegree = 70;
    float maxDegree = 130;
    float maxSpace = 30;
    if (self.type == DFPanoramaModelLitlePlanet) {
        minDegree = 90;
        maxDegree = kPlanetMaxDegree;
        maxSpace = 150 - kPlanetMaxDegree;
    } else if (self.type == DFPanoramaModelFisheye) {
        minDegree = 50;
        maxDegree = 110;
    }
    if ((self.mvpDegree <= minDegree - 30 && degree < 0) || (self.mvpDegree >= maxDegree + maxSpace && degree > 0)) {
        return 0.0;
    } else if (self.mvpDegree <= minDegree || self.mvpDegree >= maxDegree) {
        degree /= 10.0;
    } else {
        degree /= 2.0;
    }
    return degree;
}

// 设置缩放最大最小值
- (void)scaleToMaxOrdMin {
    if (!self.scaleEffect) {
        return;
    }
    float minDegree = 70;
    float maxDegree = 130;
    if (self.type == DFPanoramaModelLitlePlanet) {
        minDegree = 90;
        maxDegree = kPlanetMaxDegree;
    } else if (self.type == DFPanoramaModelFisheye) {
        minDegree = 50;
        maxDegree = 110;
    }
    
    if (self.mvpDegree < minDegree) {
        self.mvpDegree += 1;
    }else if (self.mvpDegree > maxDegree) {
        self.mvpDegree -= 1;
    } else {
        self.scaleEffect = NO;
    }
    
}

- (void)clickBtn:(UIButton *)sender {
    NSString *title = @"普通";
    switch (self.type) {
        case DFPanoramaModelNoramal:
            title = @"小行星";
            [self setPanoramicModel:DFPanoramaModelLitlePlanet];
            break;
        case DFPanoramaModelLitlePlanet:
            title = @"鱼眼";
            [self setPanoramicModel:DFPanoramaModelFisheye];
            break;
        default:
            [self setPanoramicModel:DFPanoramaModelNoramal];
            break;
    }
    [sender setTitle:title forState:UIControlStateNormal];

    
}


@end
