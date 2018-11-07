//
//  LYShaderTypes.h
//  LearnMetal
//
//  Created by loyinglin on 2018/6/21.
//  Copyright © 2018年 loyinglin. All rights reserved.
//

#ifndef LYShaderTypes_h
#define LYShaderTypes_h

#include <simd/simd.h>

typedef struct
{
    vector_float4 position;
} LYVertex;

typedef struct
{
    vector_float2 textureCoordinate;
} LYTexture;

typedef struct
{
    matrix_float4x4 mvpMatrix;
    matrix_float4x4 lookAtMatrix;
    matrix_float4x4 rotateMatrix;
} LYMatrix;



#endif /* LYShaderTypes_h */
