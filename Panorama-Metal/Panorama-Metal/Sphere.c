//
//  Sphere.c
//  VR全景图片浏览
//
//  Created by tusm on 2017/3/5.
//  Copyright © 2017年 cleven. All rights reserved.
//
#include "Sphere.h"
#include "stdlib.h"
#include "math.h"

// MARK: - 设置球体纹理

/**
 初始化球体纹理
 
 @param numSlices      帧片数
 @param radius         球体半径
 @param vertices       顶点数
 @param textCoords      坐标
 @param indices        指数
 @param numVerticesOut 顶点
 
 @return 返回球体纹理指数
 */
int initSphere(int numSlices, float radius, float fovDegree, float **vertices, float **textCoords, uint16_t **indices, int *numVerticesOut)
{
    int i;
    int j;
    int numParallels = numSlices / 2;
    int numVertices = (numParallels + 1) * (numSlices + 1);
    int numIndices = numParallels * numSlices * 6;
    float angleStep = (2.0f * M_PI) / (float)numSlices;
    
    if (vertices != NULL) {
        *vertices = malloc(sizeof(float) * 4 * numVertices);
    }
    
    if (textCoords != NULL) {
        *textCoords = malloc(sizeof(float) * 2 * numVertices);
    }
    
    if (indices != NULL) {
        *indices = malloc(sizeof(uint16_t) * numIndices);
    }
    
    for (i = 0; i < numParallels + 1; i++) {
        for (j = 0; j < numSlices + 1; j++) {
            int vertex = (i * (numSlices + 1) + j) * 4;
            
            if (vertices) {
                (*vertices)[vertex + 0] = radius * sinf(angleStep * (float)i) * sinf(angleStep * (float)j);
                (*vertices)[vertex + 1] = radius * cosf(angleStep*(float)i);
                (*vertices)[vertex + 2] = radius * sinf(angleStep * (float)i) * cosf(angleStep*(float)j);
                (*vertices)[vertex + 3] = 1.0;
            }
            
            if (textCoords) {
                int textIndex = ( i * (numSlices + 1) + j ) * 2;
                (*textCoords)[textIndex + 0] = (float) j / (float) numSlices;
                (*textCoords)[textIndex + 1] = 1.0f - ((float)i / (float)(numParallels));
            }
        }
    }
    
    if (indices != NULL) {
        uint16_t *indexBuf = (*indices);
        for (i = 0; i < numParallels * fovDegree / 360.0f; i++) {
            for (j = 0; j < numSlices; j++) {
                *indexBuf++ = i * (numSlices + 1) + j;
                *indexBuf++ = (i + 1) * (numSlices + 1) + j;
                *indexBuf++ = (i + 1) * (numSlices + 1) + ( j + 1 );
                
                *indexBuf++ = i * (numSlices + 1) + j;
                *indexBuf++ = ( i + 1 ) * (numSlices + 1) + (j + 1);
                *indexBuf++ = i * (numSlices + 1) + (j + 1);
            }
        }
    }
    
    if (numVerticesOut) {
        *numVerticesOut = numVertices;
    }
    
    return numIndices;
}


























