//
//  shaders.metal
//  LearnMetal
//
//  Created by user on 23/8/18.
//  Copyright © 2018年 Fanfan. All rights reserved.
//

#include <metal_stdlib>
#import "LYShaderTypes.h"

using namespace metal;


typedef struct
{
    float4 clipSpacePosition [[position]]; // position的修饰符表示这个是顶点
    
    float2 textureCoordinate; // 纹理坐标，会做插值处理
    
} RasterizerData;

vertex RasterizerData // 返回给片元着色器的结构体
vertexShader(uint vertexID [[ vertex_id ]], // vertex_id是顶点shader每次处理的index，用于定位当前的顶点
             constant float4 *vertexArray [[ buffer(0) ]],
             constant float2 *textureArray [[ buffer(1)]],
             constant LYMatrix *matrix [[ buffer(2)]]) { // buffer表明是缓存数据，0是索引
    RasterizerData out;
    out.clipSpacePosition = matrix->mvpMatrix * matrix->lookAtMatrix * matrix->rotateMatrix * vertexArray[vertexID];
    out.textureCoordinate = textureArray[vertexID];
    return out;
}

fragment float4
samplingShader(RasterizerData input [[stage_in]], // stage_in表示这个数据来自光栅化。（光栅化是顶点处理之后的步骤，业务层无法修改）
               texture2d<half> colorTexture [[ texture(0) ]]) // texture表明是纹理数据，0是索引
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear); // sampler是采样器
    
    half4 colorSample = colorTexture.sample(textureSampler, input.textureCoordinate); // 得到纹理对应位置的颜色
    
    return float4(colorSample);
}
