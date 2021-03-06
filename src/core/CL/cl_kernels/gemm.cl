/*
 * Copyright (c) 2017-2018 ARM Limited.
 *
 * SPDX-License-Identifier: MIT
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
#include "helpers.h"

#ifdef FIXED_POINT_POSITION
#include "fixed_point.h"
#endif // FIXED_POINT_POSITION

#if defined(TRANSPOSE_W) && defined(MULT_TRANSPOSE1XW_WIDTH)

#if ELEMENT_SIZE == 1
#define DATA_TYPE uchar
#elif ELEMENT_SIZE == 2
#define DATA_TYPE ushort
#elif ELEMENT_SIZE == 4
#define DATA_TYPE uint
#else // ELEMENT_SIZE == 1
#error "Element size not supported"
#endif // ELEMENT_SIZE

/** This OpenCL kernel computes the "vector" 1xW transposition of input matrix
 *
 * @note The transposition width must be passed at compile time using -DTRANSPOSE_W (i.e. -DTRANSPOSE_W)
 * @note The multiplication factor for the transposition width (mult_transpose1xW_width) must be passed at compile time using -DMULT_TRANSPOSE1XW_WIDTH (i.e. -DMULT_TRANSPOSE1XW_WIDTH=2)
 *
 * @param[in]  src_ptr                           Pointer to the source matrix. Supported data types: U8/S8/QS8/QASYMM8/U16/S16/QS16/F16/U32/S32/F32
 * @param[in]  src_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src_stride_z                      Stride of the source tensor in Z dimension (in bytes)
 * @param[in]  src_step_z                        src_stride_z * number of elements along Z processed per workitem(in bytes)
 * @param[in]  src_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[out] dst_ptr                           Pointer to the destination matrix Supported data types: same as @p src_ptr
 * @param[in]  dst_stride_x                      Stride of the destination matrix in X dimension (in bytes)
 * @param[in]  dst_step_x                        dst_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  dst_stride_y                      Stride of the destination matrix in Y dimension (in bytes)
 * @param[in]  dst_step_y                        dst_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  dst_stride_z                      Stride of the destination tensor in Z dimension (in bytes)
 * @param[in]  dst_step_z                        dst_stride_z * number of elements along Z processed per workitem(in bytes)
 * @param[in]  dst_offset_first_element_in_bytes The offset of the first element in the destination matrix
 */
__kernel void gemm_transpose1xW(TENSOR3D_DECLARATION(src),
                                TENSOR3D_DECLARATION(dst))
{
    uint x = get_global_id(0);
    uint y = get_global_id(1);
    uint z = get_global_id(2);

    // Compute address for Matrix B - source
    Tensor3D src = CONVERT_TO_TENSOR3D_STRUCT(src);

    // Compute address for Matrix B transposed - destination. X and Y are swapped
    uint dst_addr_in_bytes = dst_offset_first_element_in_bytes + y * TRANSPOSE_W * sizeof(DATA_TYPE) * MULT_TRANSPOSE1XW_WIDTH + (x / MULT_TRANSPOSE1XW_WIDTH) * dst_stride_y +
                             (x % MULT_TRANSPOSE1XW_WIDTH) * TRANSPOSE_W * sizeof(DATA_TYPE);

    // Add offset for batched GEMM
    dst_addr_in_bytes += z * dst_stride_z;

    VEC_DATA_TYPE(DATA_TYPE, TRANSPOSE_W)
    b0 = VLOAD(TRANSPOSE_W)(0, (__global DATA_TYPE *)src.ptr);

    VSTORE(TRANSPOSE_W)
    (b0, 0, (__global DATA_TYPE *)(dst_ptr + dst_addr_in_bytes));
}
#endif // defined(TRANSPOSE_W) && defined(MULT_TRANSPOSE1XW_WIDTH)

#if defined(MULT_INTERLEAVE4X4_HEIGHT) && defined(DATA_TYPE)

/** This OpenCL kernel reshapes the input matrix transposing each 4x4 block and interleaving the values
 *
 * @note The data type must be passed at compile time using -DDATA_TYPE (i.e. -DDATA_TYPE=float)
 * @note The multiplication factor for the height of the 4x4 interleaved block must be passed at compile time using -DMULT_INTERLEAVE4X4_HEIGHT (i.e. -DMULT_INTERLEAVE4X4_HEIGHT=2)
 *
 * @param[in]  src_ptr                           Pointer to the source matrix. Supported data types: U8/S8/QS8/QASYMM8/U16/S16/QS16/F16/U32/S32/F32
 * @param[in]  src_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src_stride_z                      Stride of the source tensor in Z dimension (in bytes)
 * @param[in]  src_step_z                        src_stride_z * number of elements along Z processed per workitem(in bytes)
 * @param[in]  src_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[out] dst_ptr                           Pointer to the destination matrix Supported data types: same as @p src_ptr
 * @param[in]  dst_stride_x                      Stride of the destination matrix in X dimension (in bytes)
 * @param[in]  dst_step_x                        dst_gx_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  dst_stride_y                      Stride of the destination matrix in Y dimension (in bytes)
 * @param[in]  dst_step_y                        dst_gx_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  dst_stride_z                      Stride of the destination tensor in Z dimension (in bytes)
 * @param[in]  dst_step_z                        dst_stride_z * number of elements along Z processed per workitem(in bytes)
 * @param[in]  dst_offset_first_element_in_bytes The offset of the first element in the destination matrix
 */
__kernel void gemm_interleave4x4(TENSOR3D_DECLARATION(src),
                                 TENSOR3D_DECLARATION(dst))
{
    // Compute source and destination addresses
    uint x = get_global_id(0);
    uint y = get_global_id(1);
    uint z = get_global_id(2);

    // Compute address for source tensor
    Tensor3D src = CONVERT_TO_TENSOR3D_STRUCT(src);

    // Compute address for Matrix B transposed - destination. X and Y are swapped
    uint dst_addr_in_bytes = dst_offset_first_element_in_bytes + x * sizeof(DATA_TYPE) * 16 * MULT_INTERLEAVE4X4_HEIGHT + (y / MULT_INTERLEAVE4X4_HEIGHT) * dst_stride_y +
                             (y % MULT_INTERLEAVE4X4_HEIGHT) * 4 * sizeof(DATA_TYPE);

    // Add offset for batched GEMM
    dst_addr_in_bytes += z * dst_stride_z;

    __global uchar *input_ptr = src.ptr;

    // Load values from Matrix A
    VEC_DATA_TYPE(DATA_TYPE, 4)
    a0 = vload4(0, (__global DATA_TYPE *)(input_ptr + 0 * src_stride_y));
    VEC_DATA_TYPE(DATA_TYPE, 4)
    a1 = vload4(0, (__global DATA_TYPE *)(input_ptr + 1 * src_stride_y));
    VEC_DATA_TYPE(DATA_TYPE, 4)
    a2 = vload4(0, (__global DATA_TYPE *)(input_ptr + 2 * src_stride_y));
    VEC_DATA_TYPE(DATA_TYPE, 4)
    a3 = vload4(0, (__global DATA_TYPE *)(input_ptr + 3 * src_stride_y));

    VEC_DATA_TYPE(DATA_TYPE, 4)
    val0 = (VEC_DATA_TYPE(DATA_TYPE, 4))(a0.s0, a1.s0, a2.s0, a3.s0);
    vstore4(val0, 0, ((__global DATA_TYPE *)(dst_ptr + dst_addr_in_bytes) + 0 * MULT_INTERLEAVE4X4_HEIGHT));

    val0 = (VEC_DATA_TYPE(DATA_TYPE, 4))(a0.s1, a1.s1, a2.s1, a3.s1);
    vstore4(val0, 0, ((__global DATA_TYPE *)(dst_ptr + dst_addr_in_bytes) + 4 * MULT_INTERLEAVE4X4_HEIGHT));

    val0 = (VEC_DATA_TYPE(DATA_TYPE, 4))(a0.s2, a1.s2, a2.s2, a3.s2);
    vstore4(val0, 0, ((__global DATA_TYPE *)(dst_ptr + dst_addr_in_bytes) + 8 * MULT_INTERLEAVE4X4_HEIGHT));

    val0 = (VEC_DATA_TYPE(DATA_TYPE, 4))(a0.s3, a1.s3, a2.s3, a3.s3);
    vstore4(val0, 0, ((__global DATA_TYPE *)(dst_ptr + dst_addr_in_bytes) + 12 * MULT_INTERLEAVE4X4_HEIGHT));
}
#endif // defined(MULT_INTERLEAVE4X4_HEIGHT) && defined(DATA_TYPE)

#if defined(COLS_B) && defined(MULT_TRANSPOSE1XW_WIDTH) && defined(MULT_INTERLEAVE4X4_HEIGHT)
/** This OpenCL kernel is optimised for Midgard. It computes the matrix multiplication between matrix A (src0) and matrix B (src1)
 *  Matrix A and matrix B must be reshaped respectively with @ref gemm_interleave4x4_32bit and @ref gemm_transpose1x4 before running the matrix multiplication
 *
 * @note The number of columns of matrix B and the optional alpha's value need to be passed at compile time using -DCOLS_B and -DALPHA
 * @note The multiplication factor for the transposition width (mult_transpose1xW_width) must be passed at compile time using -DMULT_TRANSPOSE1XW_WIDTH (i.e. -DMULT_TRANSPOSE1XW_WIDTH=2)
 * @note The multiplication factor for the height of the 4x4 interleaved block must be passed at compile time using -DMULT_INTERLEAVE4X4_HEIGHT (i.e. -DMULT_INTERLEAVE4X4_HEIGHT=2)
 * @note In case the matrix B has 3 dimensions and the matrix A more than 3, in order to avoid out-of-bounds reads, the number of channels of matrix B must be passed at compile time using MATRIX_B_DEPTH (i.e. -DMATRIX_B_DEPTH=16)
 *       This case can happen when GEMM is used to perform the element-wise multiplication through a batched matrix multiplication (2D Winograd) and we have multiple inputs (i.e. a = [K, M, 16, Batches], b = [N, K, 16])
 *
 * @param[in]  src0_ptr                           Pointer to the source matrix. Supported data types: F32
 * @param[in]  src0_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src0_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src0_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src0_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src0_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[in]  src1_ptr                           Pointer to the source matrix. Supported data types: same as @p src0_ptr
 * @param[in]  src1_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src1_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src1_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src1_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src1_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[out] dst_ptr                            Pointer to the destination matrix Supported data types: same as @p src0_ptr
 * @param[in]  dst_stride_x                       Stride of the destination matrix in X dimension (in bytes)
 * @param[in]  dst_step_x                         dst_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  dst_stride_y                       Stride of the destination matrix in Y dimension (in bytes)
 * @param[in]  dst_step_y                         dst_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  dst_offset_first_element_in_bytes  The offset of the first element in the destination matrix
 */
__kernel void gemm_mm_interleaved_transposed_f32(IMAGE_DECLARATION(src0),
                                                 IMAGE_DECLARATION(src1),
                                                 IMAGE_DECLARATION(dst),
                                                 uint src0_stride_z,
                                                 uint src1_stride_z,
                                                 uint dst_stride_z)
{
    int x = get_global_id(0) / MULT_TRANSPOSE1XW_WIDTH;
    int y = get_global_id(1) / MULT_INTERLEAVE4X4_HEIGHT;
    int z = get_global_id(2);

    // Offset
    const int offset_row_a = (get_global_id(1) % MULT_INTERLEAVE4X4_HEIGHT) * 4;
    const int offset_row_b = (get_global_id(0) % MULT_TRANSPOSE1XW_WIDTH) * 4;

    // src_addr_a = address of matrix A
    // src_addr_b = address of matrix B
    int src0_addr_in_bytes = z * src0_stride_z + y * src0_stride_y + src0_offset_first_element_in_bytes;
    int src1_addr_in_bytes = x * src1_stride_y + src1_offset_first_element_in_bytes;

#if defined(MATRIX_B_DEPTH)
    // Do not slide matrix B if the matrix B has 3 dimensions and matrix A more than 3
    src1_addr_in_bytes += (z % MATRIX_B_DEPTH) * src1_stride_z;
#else  // defined(MATRIX_B_DEPTH)
    src1_addr_in_bytes += z * src1_stride_z;
#endif // defined(MATRIX_B_DEPTH)

    __global float *src_addr_a = (__global float *)(src0_ptr + src0_addr_in_bytes);
    __global float *src_addr_b = (__global float *)(src1_ptr + src1_addr_in_bytes);

    // Compute end row address for matrix B
    __global float *src_end_addr_b = src_addr_b + COLS_B;

    src_addr_a += offset_row_a;
    src_addr_b += offset_row_b;

    // Reset accumulators
    float4 c00 = 0.0f;
    float4 c10 = 0.0f;
    float4 c20 = 0.0f;
    float4 c30 = 0.0f;

    for(; src_addr_b <= (src_end_addr_b - (int)(8 * MULT_TRANSPOSE1XW_WIDTH)); src_addr_a += 8 * MULT_INTERLEAVE4X4_HEIGHT, src_addr_b += 8 * MULT_TRANSPOSE1XW_WIDTH)
    {
        // Load values from matrix A (interleaved) and matrix B (transposed)
        float4 a0 = vload4(0, src_addr_a);
        float4 b0 = vload4(0, src_addr_b);

        c00 += (float4)a0.s0 * b0;
        c10 += (float4)a0.s1 * b0;
        c20 += (float4)a0.s2 * b0;
        c30 += (float4)a0.s3 * b0;

        // Load values from matrix A (interleaved) and matrix B (transposed)
        a0 = vload4(0, src_addr_a + 4 * MULT_INTERLEAVE4X4_HEIGHT);
        b0 = vload4(0, src_addr_b + 4 * MULT_TRANSPOSE1XW_WIDTH);

        c00 += (float4)a0.s0 * b0;
        c10 += (float4)a0.s1 * b0;
        c20 += (float4)a0.s2 * b0;
        c30 += (float4)a0.s3 * b0;
    }

    for(; src_addr_b < src_end_addr_b; src_addr_a += 4 * MULT_INTERLEAVE4X4_HEIGHT, src_addr_b += 4 * MULT_TRANSPOSE1XW_WIDTH)
    {
        // Load values from matrix A (interleaved) and matrix B (transposed)
        float4 a0 = vload4(0, src_addr_a);
        float4 b0 = vload4(0, src_addr_b);

        c00 += (float4)a0.s0 * b0;
        c10 += (float4)a0.s1 * b0;
        c20 += (float4)a0.s2 * b0;
        c30 += (float4)a0.s3 * b0;
    }

    // Compute destination address
    Image dst = CONVERT_TO_IMAGE_STRUCT(dst);

#if defined(ALPHA)
    // Multiply by the weight of matrix product
    c00 = c00 * (float4)ALPHA;
    c10 = c10 * (float4)ALPHA;
    c20 = c20 * (float4)ALPHA;
    c30 = c30 * (float4)ALPHA;
#endif // defined(ALPHA)

    // Compute dst address
    __global uchar *dst_addr = offset(&dst, 0, 0);

    // Add offset for batched GEMM
    dst_addr += z * dst_stride_z;

    // Store 4x4 block
    vstore4(c00, 0, (__global float *)(dst_addr + 0 * dst_stride_y));
    vstore4(c10, 0, (__global float *)(dst_addr + 1 * dst_stride_y));
    vstore4(c20, 0, (__global float *)(dst_addr + 2 * dst_stride_y));
    vstore4(c30, 0, (__global float *)(dst_addr + 3 * dst_stride_y));
}

/** This OpenCL kernel is optimized for Bifrost. It computes the matrix multiplication between matrix A (src0) and matrix B (src1)
 *  Matrix A and matrix B must be reshaped respectively with @ref gemm_interleave4x4_32bit and @ref gemm_transpose1x4 before running the matrix multiplication
 *
 * @note The number of columns of matrix B and the optional alpha's value need to be passed at compile time using -DCOLS_B and -DALPHA
 * @note The multiplication factor for the transposition width (mult_transpose1xW_width) must be passed at compile time using -DMULT_TRANSPOSE1XW_WIDTH (i.e. -DMULT_TRANSPOSE1XW_WIDTH=2)
 * @note The multiplication factor for the height of the 4x4 interleaved block must be passed at compile time using -DMULT_INTERLEAVE4X4_HEIGHT (i.e. -DMULT_INTERLEAVE4X4_HEIGHT=2)
 * @note The multiplication factor for the height of the 4x4 interleaved block must be passed at compile time using -DMULT_INTERLEAVE4X4_HEIGHT (i.e. -DMULT_INTERLEAVE4X4_HEIGHT=2)
 * @note In case the matrix B has 3 dimensions and the matrix A more than 3, in order to avoid out-of-bounds reads, the number of channels of matrix B must be passed at compile time using MATRIX_B_DEPTH (i.e. -DMATRIX_B_DEPTH=16)
 *       This case can happen when GEMM is used to perform the element-wise multiplication through a batched matrix multiplication (2D Winograd) and we have multiple inputs (i.e. a = [K, M, 16, Batches], b = [N, K, 16])
 *
 * @param[in]  src0_ptr                           Pointer to the source matrix. Supported data types: F32
 * @param[in]  src0_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src0_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src0_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src0_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src0_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[in]  src1_ptr                           Pointer to the source matrix. Supported data types: same as @p src0_ptr
 * @param[in]  src1_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src1_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src1_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src1_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src1_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[out] dst_ptr                            Pointer to the destination matrix Supported data types: same as @p src0_ptr
 * @param[in]  dst_stride_x                       Stride of the destination matrix in X dimension (in bytes)
 * @param[in]  dst_step_x                         dst_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  dst_stride_y                       Stride of the destination matrix in Y dimension (in bytes)
 * @param[in]  dst_step_y                         dst_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  dst_offset_first_element_in_bytes  The offset of the first element in the destination matrix
 */
__kernel void gemm_mm_interleaved_transposed_f32_bifrost(IMAGE_DECLARATION(src0),
                                                         IMAGE_DECLARATION(src1),
                                                         IMAGE_DECLARATION(dst),
                                                         uint src0_stride_z,
                                                         uint src1_stride_z,
                                                         uint dst_stride_z)
{
    int x = get_global_id(0) / MULT_TRANSPOSE1XW_WIDTH;
    int y = get_global_id(1) / MULT_INTERLEAVE4X4_HEIGHT;
    int z = get_global_id(2);

    // Offset
    const int offset_row_a = (get_global_id(1) % MULT_INTERLEAVE4X4_HEIGHT) * 4;
    const int offset_row_b = (get_global_id(0) % MULT_TRANSPOSE1XW_WIDTH) * 4;

    // src_addr_a = address of matrix A
    // src_addr_b = address of matrix B
    int src0_addr_in_bytes = z * src0_stride_z + y * src0_stride_y + src0_offset_first_element_in_bytes;
    int src1_addr_in_bytes = x * src1_stride_y + src1_offset_first_element_in_bytes;

#if defined(MATRIX_B_DEPTH)
    // Do not slide matrix B if the matrix B has 3 dimensions and matrix A more than 3
    src1_addr_in_bytes += (z % MATRIX_B_DEPTH) * src1_stride_z;
#else  // defined(MATRIX_B_DEPTH)
    src1_addr_in_bytes += z * src1_stride_z;
#endif // defined(MATRIX_B_DEPTH)

    __global float *src_addr_a = (__global float *)(src0_ptr + src0_addr_in_bytes);
    __global float *src_addr_b = (__global float *)(src1_ptr + src1_addr_in_bytes);

    src_addr_a += offset_row_a;
    src_addr_b += offset_row_b;

    // Reset accumulators
    float c00 = 0.0f;
    float c01 = 0.0f;
    float c02 = 0.0f;
    float c03 = 0.0f;
    float c10 = 0.0f;
    float c11 = 0.0f;
    float c12 = 0.0f;
    float c13 = 0.0f;
    float c20 = 0.0f;
    float c21 = 0.0f;
    float c22 = 0.0f;
    float c23 = 0.0f;
    float c30 = 0.0f;
    float c31 = 0.0f;
    float c32 = 0.0f;
    float c33 = 0.0f;

#define COLS_MTX_B (COLS_B / (4 * MULT_TRANSPOSE1XW_WIDTH))

    int i = 0;
    for(; i <= (int)(COLS_MTX_B - 4); i += 4)
    {
        // Load values from matrix A (interleaved) and matrix B (transposed)
        float4 a0 = vload4(0, src_addr_a);
        float4 b0 = vload4(0, src_addr_b);

        src_addr_a += 4 * MULT_INTERLEAVE4X4_HEIGHT;
        src_addr_b += 4 * MULT_TRANSPOSE1XW_WIDTH;

        c00 = fma(a0.s0, b0.s0, c00);
        c01 = fma(a0.s0, b0.s1, c01);
        c02 = fma(a0.s0, b0.s2, c02);
        c03 = fma(a0.s0, b0.s3, c03);

        c10 = fma(a0.s1, b0.s0, c10);
        c11 = fma(a0.s1, b0.s1, c11);
        c12 = fma(a0.s1, b0.s2, c12);
        c13 = fma(a0.s1, b0.s3, c13);

        c20 = fma(a0.s2, b0.s0, c20);
        c21 = fma(a0.s2, b0.s1, c21);
        c22 = fma(a0.s2, b0.s2, c22);
        c23 = fma(a0.s2, b0.s3, c23);

        c30 = fma(a0.s3, b0.s0, c30);
        c31 = fma(a0.s3, b0.s1, c31);
        c32 = fma(a0.s3, b0.s2, c32);
        c33 = fma(a0.s3, b0.s3, c33);

        // Load values from matrix A (interleaved) and matrix B (transposed)
        a0 = vload4(0, src_addr_a);
        b0 = vload4(0, src_addr_b);

        src_addr_a += 4 * MULT_INTERLEAVE4X4_HEIGHT;
        src_addr_b += 4 * MULT_TRANSPOSE1XW_WIDTH;

        c00 = fma(a0.s0, b0.s0, c00);
        c01 = fma(a0.s0, b0.s1, c01);
        c02 = fma(a0.s0, b0.s2, c02);
        c03 = fma(a0.s0, b0.s3, c03);

        c10 = fma(a0.s1, b0.s0, c10);
        c11 = fma(a0.s1, b0.s1, c11);
        c12 = fma(a0.s1, b0.s2, c12);
        c13 = fma(a0.s1, b0.s3, c13);

        c20 = fma(a0.s2, b0.s0, c20);
        c21 = fma(a0.s2, b0.s1, c21);
        c22 = fma(a0.s2, b0.s2, c22);
        c23 = fma(a0.s2, b0.s3, c23);

        c30 = fma(a0.s3, b0.s0, c30);
        c31 = fma(a0.s3, b0.s1, c31);
        c32 = fma(a0.s3, b0.s2, c32);
        c33 = fma(a0.s3, b0.s3, c33);

        // Load values from matrix A (interleaved) and matrix B (transposed)
        a0 = vload4(0, src_addr_a);
        b0 = vload4(0, src_addr_b);

        src_addr_a += 4 * MULT_INTERLEAVE4X4_HEIGHT;
        src_addr_b += 4 * MULT_TRANSPOSE1XW_WIDTH;

        c00 = fma(a0.s0, b0.s0, c00);
        c01 = fma(a0.s0, b0.s1, c01);
        c02 = fma(a0.s0, b0.s2, c02);
        c03 = fma(a0.s0, b0.s3, c03);

        c10 = fma(a0.s1, b0.s0, c10);
        c11 = fma(a0.s1, b0.s1, c11);
        c12 = fma(a0.s1, b0.s2, c12);
        c13 = fma(a0.s1, b0.s3, c13);

        c20 = fma(a0.s2, b0.s0, c20);
        c21 = fma(a0.s2, b0.s1, c21);
        c22 = fma(a0.s2, b0.s2, c22);
        c23 = fma(a0.s2, b0.s3, c23);

        c30 = fma(a0.s3, b0.s0, c30);
        c31 = fma(a0.s3, b0.s1, c31);
        c32 = fma(a0.s3, b0.s2, c32);
        c33 = fma(a0.s3, b0.s3, c33);

        // Load values from matrix A (interleaved) and matrix B (transposed)
        a0 = vload4(0, src_addr_a);
        b0 = vload4(0, src_addr_b);

        src_addr_a += 4 * MULT_INTERLEAVE4X4_HEIGHT;
        src_addr_b += 4 * MULT_TRANSPOSE1XW_WIDTH;

        c00 = fma(a0.s0, b0.s0, c00);
        c01 = fma(a0.s0, b0.s1, c01);
        c02 = fma(a0.s0, b0.s2, c02);
        c03 = fma(a0.s0, b0.s3, c03);

        c10 = fma(a0.s1, b0.s0, c10);
        c11 = fma(a0.s1, b0.s1, c11);
        c12 = fma(a0.s1, b0.s2, c12);
        c13 = fma(a0.s1, b0.s3, c13);

        c20 = fma(a0.s2, b0.s0, c20);
        c21 = fma(a0.s2, b0.s1, c21);
        c22 = fma(a0.s2, b0.s2, c22);
        c23 = fma(a0.s2, b0.s3, c23);

        c30 = fma(a0.s3, b0.s0, c30);
        c31 = fma(a0.s3, b0.s1, c31);
        c32 = fma(a0.s3, b0.s2, c32);
        c33 = fma(a0.s3, b0.s3, c33);
    }

    for(; i < (int)(COLS_MTX_B); ++i)
    {
        // Load values from matrix A (interleaved) and matrix B (transposed)
        float4 a0 = vload4(0, src_addr_a);
        float4 b0 = vload4(0, src_addr_b);

        src_addr_a += 4 * MULT_INTERLEAVE4X4_HEIGHT;
        src_addr_b += 4 * MULT_TRANSPOSE1XW_WIDTH;

        c00 = fma(a0.s0, b0.s0, c00);
        c01 = fma(a0.s0, b0.s1, c01);
        c02 = fma(a0.s0, b0.s2, c02);
        c03 = fma(a0.s0, b0.s3, c03);

        c10 = fma(a0.s1, b0.s0, c10);
        c11 = fma(a0.s1, b0.s1, c11);
        c12 = fma(a0.s1, b0.s2, c12);
        c13 = fma(a0.s1, b0.s3, c13);

        c20 = fma(a0.s2, b0.s0, c20);
        c21 = fma(a0.s2, b0.s1, c21);
        c22 = fma(a0.s2, b0.s2, c22);
        c23 = fma(a0.s2, b0.s3, c23);

        c30 = fma(a0.s3, b0.s0, c30);
        c31 = fma(a0.s3, b0.s1, c31);
        c32 = fma(a0.s3, b0.s2, c32);
        c33 = fma(a0.s3, b0.s3, c33);
    }

    // Compute destination address
    Image dst = CONVERT_TO_IMAGE_STRUCT(dst);

#if defined(ALPHA)
    // Multiply by the weight of matrix product
    c00 = c00 * ALPHA;
    c01 = c01 * ALPHA;
    c02 = c02 * ALPHA;
    c03 = c03 * ALPHA;
    c10 = c10 * ALPHA;
    c11 = c11 * ALPHA;
    c12 = c12 * ALPHA;
    c13 = c13 * ALPHA;
    c20 = c20 * ALPHA;
    c21 = c21 * ALPHA;
    c22 = c22 * ALPHA;
    c23 = c23 * ALPHA;
    c30 = c30 * ALPHA;
    c31 = c31 * ALPHA;
    c32 = c32 * ALPHA;
    c33 = c33 * ALPHA;
#endif // defined(ALPHA)

    // Compute dst address
    __global uchar *dst_addr = offset(&dst, 0, 0);

    // Add offset for batched GEMM
    dst_addr += z * dst_stride_z;

    // Store 4x4 block
    vstore4((float4)(c00, c01, c02, c03), 0, (__global float *)(dst_addr + 0 * dst_stride_y));
    vstore4((float4)(c10, c11, c12, c13), 0, (__global float *)(dst_addr + 1 * dst_stride_y));
    vstore4((float4)(c20, c21, c22, c23), 0, (__global float *)(dst_addr + 2 * dst_stride_y));
    vstore4((float4)(c30, c31, c32, c33), 0, (__global float *)(dst_addr + 3 * dst_stride_y));
}

// Undefine local defines
#undef COLS_MTX_B

#if defined(ARM_COMPUTE_OPENCL_FP16_ENABLED)
/** This OpenCL kernel computes the matrix multiplication between matrix A (src0) and matrix B (src1)
 *  Matrix A and matrix B must be reshaped respectively with @ref gemm_interleave4x4_16bit and @ref gemm_transpose1x8 before running the matrix multiplication
 *
 * @note The number of columns of matrix B and the optional alpha's value need to be passed at compile time using -DCOLS_B and -DALPHA
 * @note The multiplication factor for the transposition width (mult_transpose1xW_width) must be passed at compile time using -DMULT_TRANSPOSE1XW_WIDTH (i.e. -DMULT_TRANSPOSE1XW_WIDTH=2)
 * @note The multiplication factor for the height of the 4x4 interleaved block must be passed at compile time using -DMULT_INTERLEAVE4X4_HEIGHT (i.e. -DMULT_INTERLEAVE4X4_HEIGHT=2)
 * @note In case the matrix B has 3 dimensions and the matrix A more than 3, in order to avoid out-of-bounds reads, the number of channels of matrix B must be passed at compile time using MATRIX_B_DEPTH (i.e. -DMATRIX_B_DEPTH=16)
 *       This case can happen when GEMM is used to perform the element-wise multiplication through a batched matrix multiplication (2D Winograd) and we have multiple inputs (i.e. a = [K, M, 16, Batches], b = [N, K, 16])
 *
 * @param[in]  src0_ptr                           Pointer to the source matrix. Supported data types: F16
 * @param[in]  src0_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src0_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src0_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src0_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src0_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[in]  src1_ptr                           Pointer to the source matrix. Supported data types: same as @p src0_ptr
 * @param[in]  src1_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src1_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src1_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src1_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src1_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[out] dst_ptr                            Pointer to the destination matrix Supported data types: same as @p src0_ptr
 * @param[in]  dst_stride_x                       Stride of the destination matrix in X dimension (in bytes)
 * @param[in]  dst_step_x                         dst_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  dst_stride_y                       Stride of the destination matrix in Y dimension (in bytes)
 * @param[in]  dst_step_y                         dst_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  dst_offset_first_element_in_bytes  The offset of the first element in the destination matrix
 */
__kernel void gemm_mm_interleaved_transposed_f16(IMAGE_DECLARATION(src0),
                                                 IMAGE_DECLARATION(src1),
                                                 IMAGE_DECLARATION(dst),
                                                 uint src0_stride_z,
                                                 uint src1_stride_z,
                                                 uint dst_stride_z)
{
    int x = get_global_id(0) / MULT_TRANSPOSE1XW_WIDTH;
    int y = get_global_id(1) / MULT_INTERLEAVE4X4_HEIGHT;
    int z = get_global_id(2);

    // Offset
    const int offset_row_a = (get_global_id(1) % MULT_INTERLEAVE4X4_HEIGHT) * 4;
    const int offset_row_b = (get_global_id(0) % MULT_TRANSPOSE1XW_WIDTH) * 8;

    // src_addr_a = address of matrix A
    // src_addr_b = address of matrix B
    int src0_addr_in_bytes = z * src0_stride_z + y * src0_stride_y + src0_offset_first_element_in_bytes;
    int src1_addr_in_bytes = x * src1_stride_y + src1_offset_first_element_in_bytes;

#if defined(MATRIX_B_DEPTH)
    // Do not slide matrix B if the matrix B has 3 dimensions and matrix A more than 3
    src1_addr_in_bytes += (z % MATRIX_B_DEPTH) * src1_stride_z;
#else  // defined(MATRIX_B_DEPTH)
    src1_addr_in_bytes += z * src1_stride_z;
#endif // defined(MATRIX_B_DEPTH)

    __global half *src_addr_a = (__global half *)(src0_ptr + src0_addr_in_bytes);
    __global half *src_addr_b = (__global half *)(src1_ptr + src1_addr_in_bytes);

    // Compute end row address for matrix B
    __global half *src_end_addr_b = src_addr_b + COLS_B;

    src_addr_a += offset_row_a;
    src_addr_b += offset_row_b;

    // Reset accumulators
    half8 c00 = 0.0f;
    half8 c10 = 0.0f;
    half8 c20 = 0.0f;
    half8 c30 = 0.0f;

    for(; src_addr_b <= (src_end_addr_b - (int)(16 * MULT_TRANSPOSE1XW_WIDTH)); src_addr_a += 8 * MULT_INTERLEAVE4X4_HEIGHT, src_addr_b += 16 * MULT_TRANSPOSE1XW_WIDTH)
    {
        // Load values from matrix A (interleaved) and matrix B (transposed)
        half4 a0 = vload4(0, src_addr_a);
        half8 b0 = vload8(0, src_addr_b);

        c00 += (half8)a0.s0 * b0;
        c10 += (half8)a0.s1 * b0;
        c20 += (half8)a0.s2 * b0;
        c30 += (half8)a0.s3 * b0;

        // Load values from matrix A (interleaved) and matrix B (transposed)
        a0 = vload4(0, src_addr_a + 4 * MULT_INTERLEAVE4X4_HEIGHT);
        b0 = vload8(0, src_addr_b + 8 * MULT_TRANSPOSE1XW_WIDTH);

        c00 += (half8)a0.s0 * b0;
        c10 += (half8)a0.s1 * b0;
        c20 += (half8)a0.s2 * b0;
        c30 += (half8)a0.s3 * b0;
    }

    for(; src_addr_b < src_end_addr_b; src_addr_a += 4 * MULT_INTERLEAVE4X4_HEIGHT, src_addr_b += 8 * MULT_TRANSPOSE1XW_WIDTH)
    {
        // Load values from matrix A (interleaved) and matrix B (transposed)
        half4 a0 = vload4(0, src_addr_a);
        half8 b0 = vload8(0, src_addr_b);

        c00 += (half8)a0.s0 * b0;
        c10 += (half8)a0.s1 * b0;
        c20 += (half8)a0.s2 * b0;
        c30 += (half8)a0.s3 * b0;
    }

    // Compute destination address
    Image dst = CONVERT_TO_IMAGE_STRUCT(dst);

#if defined(ALPHA)
    // Multiply by the weight of matrix product
    c00 = c00 * (half8)ALPHA;
    c10 = c10 * (half8)ALPHA;
    c20 = c20 * (half8)ALPHA;
    c30 = c30 * (half8)ALPHA;
#endif // defined(ALPHA)

    // Compute dst address
    __global uchar *dst_addr = offset(&dst, 0, 0);

    // Add offset for batched GEMM
    dst_addr += z * dst_stride_z;

    // Store 4x8 block
    vstore8(c00, 0, (__global half *)(dst_addr + 0 * dst_stride_y));
    vstore8(c10, 0, (__global half *)(dst_addr + 1 * dst_stride_y));
    vstore8(c20, 0, (__global half *)(dst_addr + 2 * dst_stride_y));
    vstore8(c30, 0, (__global half *)(dst_addr + 3 * dst_stride_y));
}

/** This OpenCL kernel optimized for Bifrost architectures computes the matrix multiplication between matrix A (src0) and matrix B (src1)
 *  Matrix A and matrix B must be reshaped respectively with @ref gemm_interleave4x4_16bit and @ref gemm_transpose1x8 before running the matrix multiplication
 *
 * @note The number of columns of matrix B and the optional alpha's value need to be passed at compile time using -DCOLS_B and -DALPHA
 * @note The multiplication factor for the transposition width (mult_transpose1xW_width) must be passed at compile time using -DMULT_TRANSPOSE1XW_WIDTH (i.e. -DMULT_TRANSPOSE1XW_WIDTH=2)
 * @note The multiplication factor for the height of the 4x4 interleaved block must be passed at compile time using -DMULT_INTERLEAVE4X4_HEIGHT (i.e. -DMULT_INTERLEAVE4X4_HEIGHT=2)
 * @note In case the matrix B has 3 dimensions and the matrix A more than 3, in order to avoid out-of-bounds reads, the number of channels of matrix B must be passed at compile time using MATRIX_B_DEPTH (i.e. -DMATRIX_B_DEPTH=16)
 *       This case can happen when GEMM is used to perform the element-wise multiplication through a batched matrix multiplication (2D Winograd) and we have multiple inputs (i.e. a = [K, M, 16, Batches], b = [N, K, 16])
 *
 * @param[in]  src0_ptr                           Pointer to the source matrix. Supported data types: F16
 * @param[in]  src0_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src0_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src0_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src0_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src0_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[in]  src1_ptr                           Pointer to the source matrix. Supported data types: same as @p src0_ptr
 * @param[in]  src1_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src1_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src1_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src1_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src1_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[out] dst_ptr                            Pointer to the destination matrix Supported data types: same as @p src0_ptr
 * @param[in]  dst_stride_x                       Stride of the destination matrix in X dimension (in bytes)
 * @param[in]  dst_step_x                         dst_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  dst_stride_y                       Stride of the destination matrix in Y dimension (in bytes)
 * @param[in]  dst_step_y                         dst_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  dst_offset_first_element_in_bytes  The offset of the first element in the destination matrix
 */
__kernel void gemm_mm_interleaved_transposed_f16_bifrost(IMAGE_DECLARATION(src0),
                                                         IMAGE_DECLARATION(src1),
                                                         IMAGE_DECLARATION(dst),
                                                         uint src0_stride_z,
                                                         uint src1_stride_z,
                                                         uint dst_stride_z)
{
    int x = get_global_id(0) / MULT_TRANSPOSE1XW_WIDTH;
    int y = get_global_id(1) / MULT_INTERLEAVE4X4_HEIGHT;
    int z = get_global_id(2);

    // Offset
    const int offset_row_a = (get_global_id(1) % MULT_INTERLEAVE4X4_HEIGHT) * 4;
    const int offset_row_b = (get_global_id(0) % MULT_TRANSPOSE1XW_WIDTH) * 8;

    // src_addr_a = address of matrix A
    // src_addr_b = address of matrix B
    int src0_addr_in_bytes = z * src0_stride_z + y * src0_stride_y + src0_offset_first_element_in_bytes;
    int src1_addr_in_bytes = x * src1_stride_y + src1_offset_first_element_in_bytes;

#if defined(MATRIX_B_DEPTH)
    // Do not slide matrix B if the matrix B has 3 dimensions and matrix A more than 3
    src1_addr_in_bytes += (z % MATRIX_B_DEPTH) * src1_stride_z;
#else  // defined(MATRIX_B_DEPTH)
    src1_addr_in_bytes += z * src1_stride_z;
#endif // defined(MATRIX_B_DEPTH)

    __global half *src_addr_a = (__global half *)(src0_ptr + src0_addr_in_bytes);
    __global half *src_addr_b = (__global half *)(src1_ptr + src1_addr_in_bytes);

    // Compute end row address for matrix B
    __global half *src_end_addr_b = src_addr_b + COLS_B;

    src_addr_a += offset_row_a;
    src_addr_b += offset_row_b;

    // Reset accumulators
    half8 c00 = 0.0f;
    half8 c10 = 0.0f;
    half8 c20 = 0.0f;
    half8 c30 = 0.0f;

#define COLS_MTX_B (COLS_B / (8 * MULT_TRANSPOSE1XW_WIDTH))

    int i = 0;
    for(; i <= (int)(COLS_MTX_B - 4); i += 4)
    {
#if MULT_INTERLEAVE4X4_HEIGHT == 1
        // Load values from matrix A (interleaved) and matrix B (transposed)
        half8 a0 = vload8(0, src_addr_a);
        half8 b0 = vload8(0, src_addr_b);

        src_addr_a += 8 * MULT_INTERLEAVE4X4_HEIGHT;
        src_addr_b += 8 * MULT_TRANSPOSE1XW_WIDTH;

        c00 = fma((half8)a0.s0, b0, c00);
        c10 = fma((half8)a0.s1, b0, c10);
        c20 = fma((half8)a0.s2, b0, c20);
        c30 = fma((half8)a0.s3, b0, c30);

        // Load values from matrix B (transposed)
        b0 = vload8(0, src_addr_b);

        src_addr_b += 8 * MULT_TRANSPOSE1XW_WIDTH;

        c00 = fma((half8)a0.s4, b0, c00);
        c10 = fma((half8)a0.s5, b0, c10);
        c20 = fma((half8)a0.s6, b0, c20);
        c30 = fma((half8)a0.s7, b0, c30);

        // Load values from matrix A (interleaved) and matrix B (transposed)
        a0 = vload8(0, src_addr_a);
        b0 = vload8(0, src_addr_b);

        src_addr_a += 8 * MULT_INTERLEAVE4X4_HEIGHT;
        src_addr_b += 8 * MULT_TRANSPOSE1XW_WIDTH;

        c00 = fma((half8)a0.s0, b0, c00);
        c10 = fma((half8)a0.s1, b0, c10);
        c20 = fma((half8)a0.s2, b0, c20);
        c30 = fma((half8)a0.s3, b0, c30);

        // Load values from matrix B (transposed)
        b0 = vload8(0, src_addr_b);

        src_addr_b += 8 * MULT_TRANSPOSE1XW_WIDTH;

        c00 = fma((half8)a0.s4, b0, c00);
        c10 = fma((half8)a0.s5, b0, c10);
        c20 = fma((half8)a0.s6, b0, c20);
        c30 = fma((half8)a0.s7, b0, c30);
#else  // MULT_INTERLEAVE4X4_HEIGHT == 1
        // Load values from matrix A (interleaved) and matrix B (transposed)
        half4 a0 = vload4(0, src_addr_a);
        half8 b0 = vload8(0, src_addr_b);

        src_addr_a += 4 * MULT_INTERLEAVE4X4_HEIGHT;
        src_addr_b += 8 * MULT_TRANSPOSE1XW_WIDTH;

        c00 = fma((half8)a0.s0, b0, c00);
        c10 = fma((half8)a0.s1, b0, c10);
        c20 = fma((half8)a0.s2, b0, c20);
        c30 = fma((half8)a0.s3, b0, c30);

        // Load values from matrix A (interleaved) and matrix B (transposed)
        a0 = vload4(0, src_addr_a);
        b0 = vload8(0, src_addr_b);

        src_addr_a += 4 * MULT_INTERLEAVE4X4_HEIGHT;
        src_addr_b += 8 * MULT_TRANSPOSE1XW_WIDTH;

        c00 = fma((half8)a0.s0, b0, c00);
        c10 = fma((half8)a0.s1, b0, c10);
        c20 = fma((half8)a0.s2, b0, c20);
        c30 = fma((half8)a0.s3, b0, c30);

        // Load values from matrix A (interleaved) and matrix B (transposed)
        a0 = vload4(0, src_addr_a);
        b0 = vload8(0, src_addr_b);

        src_addr_a += 4 * MULT_INTERLEAVE4X4_HEIGHT;
        src_addr_b += 8 * MULT_TRANSPOSE1XW_WIDTH;

        c00 = fma((half8)a0.s0, b0, c00);
        c10 = fma((half8)a0.s1, b0, c10);
        c20 = fma((half8)a0.s2, b0, c20);
        c30 = fma((half8)a0.s3, b0, c30);

        // Load values from matrix A (interleaved) and matrix B (transposed)
        a0 = vload4(0, src_addr_a);
        b0 = vload8(0, src_addr_b);

        src_addr_a += 4 * MULT_INTERLEAVE4X4_HEIGHT;
        src_addr_b += 8 * MULT_TRANSPOSE1XW_WIDTH;

        c00 = fma((half8)a0.s0, b0, c00);
        c10 = fma((half8)a0.s1, b0, c10);
        c20 = fma((half8)a0.s2, b0, c20);
        c30 = fma((half8)a0.s3, b0, c30);
#endif // MULT_INTERLEAVE4X4_HEIGHT == 1
    }

    for(; i < (int)(COLS_MTX_B); ++i)
    {
        // Load values from matrix A (interleaved) and matrix B (transposed)
        half4 a0 = vload4(0, src_addr_a);
        half8 b0 = vload8(0, src_addr_b);

        src_addr_a += 4 * MULT_INTERLEAVE4X4_HEIGHT;
        src_addr_b += 8 * MULT_TRANSPOSE1XW_WIDTH;

        c00 = fma((half8)a0.s0, b0, c00);
        c10 = fma((half8)a0.s1, b0, c10);
        c20 = fma((half8)a0.s2, b0, c20);
        c30 = fma((half8)a0.s3, b0, c30);
    }

    // Compute destination address
    Image dst = CONVERT_TO_IMAGE_STRUCT(dst);

#if defined(ALPHA)
    // Multiply by the weight of matrix product
    c00 = c00 * (half8)ALPHA;
    c10 = c10 * (half8)ALPHA;
    c20 = c20 * (half8)ALPHA;
    c30 = c30 * (half8)ALPHA;
#endif // defined(ALPHA)

    // Compute dst address
    __global uchar *dst_addr = offset(&dst, 0, 0);

    // Add offset for batched GEMM
    dst_addr += z * dst_stride_z;

    // Store 4x8 block
    vstore8(c00, 0, (__global half *)(dst_addr + 0 * dst_stride_y));
    vstore8(c10, 0, (__global half *)(dst_addr + 1 * dst_stride_y));
    vstore8(c20, 0, (__global half *)(dst_addr + 2 * dst_stride_y));
    vstore8(c30, 0, (__global half *)(dst_addr + 3 * dst_stride_y));
}

// Undefine local defines
#undef COLS_MTX_B

#endif // defined(ARM_COMPUTE_OPENCL_FP16_ENABLED)

#if defined(FIXED_POINT_POSITION)
/** This OpenCL kernel computes the matrix multiplication between matrix A (src0) and matrix B (src1) in 8 bit fixed point precision
 *  Matrix A and matrix B must be reshaped respectively with @ref gemm_interleave4x4_8bit and @ref gemm_transpose1x16 before running the matrix multiplication
 *
 * @note The number of columns of matrix B and the optional alpha's value need to be passed at compile time using -DCOLS_B and -DALPHA
 * @note The multiplication factor for the transposition width (mult_transpose1xW_width) must be passed at compile time using -DMULT_TRANSPOSE1XW_WIDTH (i.e. -DMULT_TRANSPOSE1XW_WIDTH=2)
 * @note The multiplication factor for the height of the 4x4 interleaved block must be passed at compile time using -DMULT_INTERLEAVE4X4_HEIGHT (i.e. -DMULT_INTERLEAVE4X4_HEIGHT=2)
 * @note In case the matrix B has 3 dimensions and the matrix A more than 3, in order to avoid out-of-bounds reads, the number of channels of matrix B must be passed at compile time using MATRIX_B_DEPTH (i.e. -DMATRIX_B_DEPTH=16)
 *       This case can happen when GEMM is used to perform the element-wise multiplication through a batched matrix multiplication (2D Winograd) and we have multiple inputs (i.e. a = [K, M, 16, Batches], b = [N, K, 16])
 * @note:ALPHA must be passed in 8 bit fixed point format
 *
 * @param[in]  src0_ptr                           Pointer to the source matrix. Supported data types: QS8
 * @param[in]  src0_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src0_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src0_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src0_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src0_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[in]  src1_ptr                           Pointer to the source matrix. Supported data types: same as @p src0_ptr
 * @param[in]  src1_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src1_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src1_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src1_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src1_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[out] dst_ptr                            Pointer to the destination matrix Supported data types: same as @p src0_ptr
 * @param[in]  dst_stride_x                       Stride of the destination matrix in X dimension (in bytes)
 * @param[in]  dst_step_x                         dst_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  dst_stride_y                       Stride of the destination matrix in Y dimension (in bytes)
 * @param[in]  dst_step_y                         dst_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  dst_offset_first_element_in_bytes  The offset of the first element in the destination matrix
 */
__kernel void gemm_mm_interleaved_transposed_qs8(IMAGE_DECLARATION(src0),
                                                 IMAGE_DECLARATION(src1),
                                                 IMAGE_DECLARATION(dst),
                                                 uint src0_stride_z,
                                                 uint src1_stride_z,
                                                 uint dst_stride_z)
{
    int x = get_global_id(0) / MULT_TRANSPOSE1XW_WIDTH;
    int y = get_global_id(1) / MULT_INTERLEAVE4X4_HEIGHT;
    int z = get_global_id(2);

    // Offset
    const int offset_row_a = (get_global_id(1) % MULT_INTERLEAVE4X4_HEIGHT) * 4;
    const int offset_row_b = (get_global_id(0) % MULT_TRANSPOSE1XW_WIDTH) * 16;

    // src_addr_a = address of matrix A
    // src_addr_b = address of matrix B
    int src0_addr_in_bytes = z * src0_stride_z + y * src0_stride_y + src0_offset_first_element_in_bytes;
    int src1_addr_in_bytes = x * src1_stride_y + src1_offset_first_element_in_bytes;

#if defined(MATRIX_B_DEPTH)
    // Do not slide matrix B if the matrix B has 3 dimensions and matrix A more than 3
    src1_addr_in_bytes += (z % MATRIX_B_DEPTH) * src1_stride_z;
#else  // defined(MATRIX_B_DEPTH)
    src1_addr_in_bytes += z * src1_stride_z;
#endif // defined(MATRIX_B_DEPTH)

    __global char *src_addr_a = (__global char *)(src0_ptr + src0_addr_in_bytes);
    __global char *src_addr_b = (__global char *)(src1_ptr + src1_addr_in_bytes);

    // Compute end row address for matrix B
    __global char *src_end_addr_b = src_addr_b + COLS_B;

    src_addr_a += offset_row_a;
    src_addr_b += offset_row_b;

    // Reset accumulators
    short8 c00 = 0.0f;
    short8 c10 = 0.0f;
    short8 c20 = 0.0f;
    short8 c30 = 0.0f;
    short8 c01 = 0.0f;
    short8 c11 = 0.0f;
    short8 c21 = 0.0f;
    short8 c31 = 0.0f;

    // This for loop performs 1 accumulation for each iteration
    for(; src_addr_b < src_end_addr_b; src_addr_a += 4 * MULT_INTERLEAVE4X4_HEIGHT, src_addr_b += 16 * MULT_TRANSPOSE1XW_WIDTH)
    {
        // Load values from matrix A (interleaved) and matrix B (transposed)
        char4  a0 = vload4(0, src_addr_a);
        char16 b0 = vload16(0, src_addr_b);

        c00 = mlal_sat_qs8x8(c00, (char8)a0.s0, b0.s01234567, FIXED_POINT_POSITION);
        c10 = mlal_sat_qs8x8(c10, (char8)a0.s1, b0.s01234567, FIXED_POINT_POSITION);
        c20 = mlal_sat_qs8x8(c20, (char8)a0.s2, b0.s01234567, FIXED_POINT_POSITION);
        c30 = mlal_sat_qs8x8(c30, (char8)a0.s3, b0.s01234567, FIXED_POINT_POSITION);

        c01 = mlal_sat_qs8x8(c01, (char8)a0.s0, b0.s89ABCDEF, FIXED_POINT_POSITION);
        c11 = mlal_sat_qs8x8(c11, (char8)a0.s1, b0.s89ABCDEF, FIXED_POINT_POSITION);
        c21 = mlal_sat_qs8x8(c21, (char8)a0.s2, b0.s89ABCDEF, FIXED_POINT_POSITION);
        c31 = mlal_sat_qs8x8(c31, (char8)a0.s3, b0.s89ABCDEF, FIXED_POINT_POSITION);
    }

    // Compute destination address
    Image dst = CONVERT_TO_IMAGE_STRUCT(dst);

    // Multiply by the weight of matrix product
    char16 c00_qs8 = convert_char16_sat((short16)(c00, c01));
    char16 c10_qs8 = convert_char16_sat((short16)(c10, c11));
    char16 c20_qs8 = convert_char16_sat((short16)(c20, c21));
    char16 c30_qs8 = convert_char16_sat((short16)(c30, c31));

#if defined(ALPHA)
    c00_qs8 = mul_sat_qs8x16(c00_qs8, (char16)ALPHA, FIXED_POINT_POSITION);
    c10_qs8 = mul_sat_qs8x16(c10_qs8, (char16)ALPHA, FIXED_POINT_POSITION);
    c20_qs8 = mul_sat_qs8x16(c20_qs8, (char16)ALPHA, FIXED_POINT_POSITION);
    c30_qs8 = mul_sat_qs8x16(c30_qs8, (char16)ALPHA, FIXED_POINT_POSITION);
#endif // defined(ALPHA)

    // Compute dst address
    __global uchar *dst_addr = offset(&dst, 0, 0);

    // Add offset for batched GEMM
    dst_addr += z * dst_stride_z;

    // Store 16x4 block
    vstore16(c00_qs8, 0, (__global char *)(dst_addr + 0 * dst_stride_y));
    vstore16(c10_qs8, 0, (__global char *)(dst_addr + 1 * dst_stride_y));
    vstore16(c20_qs8, 0, (__global char *)(dst_addr + 2 * dst_stride_y));
    vstore16(c30_qs8, 0, (__global char *)(dst_addr + 3 * dst_stride_y));
}

/** This OpenCL kernel computes the matrix multiplication between matrix A (src0) and matrix B (src1) in 16 bit fixed point precision
 *  Matrix A and matrix B must be reshaped respectively with @ref gemm_interleave4x4_16bit and @ref gemm_transpose1x8 before running the matrix multiplication
 *
 * @note The number of columns of matrix B and the optional alpha's value need to be passed at compile time using -DCOLS_B and -DALPHA
 * @note The multiplication factor for the transposition width (mult_transpose1xW_width) must be passed at compile time using -DMULT_TRANSPOSE1XW_WIDTH (i.e. -DMULT_TRANSPOSE1XW_WIDTH=2)
 * @note The multiplication factor for the height of the 4x4 interleaved block must be passed at compile time using -DMULT_INTERLEAVE4X4_HEIGHT (i.e. -DMULT_INTERLEAVE4X4_HEIGHT=2)
 * @note In case the matrix B has 3 dimensions and the matrix A more than 3, in order to avoid out-of-bounds reads, the number of channels of matrix B must be passed at compile time using MATRIX_B_DEPTH (i.e. -DMATRIX_B_DEPTH=16)
 *       This case can happen when GEMM is used to perform the element-wise multiplication through a batched matrix multiplication (2D Winograd) and we have multiple inputs (i.e. a = [K, M, 16, Batches], b = [N, K, 16])
 * @note:ALPHA must be passed in 16 bit fixed point format
 *
 * @param[in]  src0_ptr                           Pointer to the source matrix. Supported data types: QS16
 * @param[in]  src0_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src0_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src0_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src0_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src0_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[in]  src1_ptr                           Pointer to the source matrix. Supported data types: same as @p src0_ptr
 * @param[in]  src1_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src1_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src1_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src1_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src1_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[out] dst_ptr                            Pointer to the destination matrix Supported data types: same as @p src0_ptr
 * @param[in]  dst_stride_x                       Stride of the destination matrix in X dimension (in bytes)
 * @param[in]  dst_step_x                         dst_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  dst_stride_y                       Stride of the destination matrix in Y dimension (in bytes)
 * @param[in]  dst_step_y                         dst_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  dst_offset_first_element_in_bytes  The offset of the first element in the destination matrix
 */
__kernel void gemm_mm_interleaved_transposed_qs16(IMAGE_DECLARATION(src0),
                                                  IMAGE_DECLARATION(src1),
                                                  IMAGE_DECLARATION(dst),
                                                  uint src0_stride_z,
                                                  uint src1_stride_z,
                                                  uint dst_stride_z)
{
    int x = get_global_id(0) / MULT_TRANSPOSE1XW_WIDTH;
    int y = get_global_id(1) / MULT_INTERLEAVE4X4_HEIGHT;
    int z = get_global_id(2);

    // Offset
    const int offset_row_a = (get_global_id(1) % MULT_INTERLEAVE4X4_HEIGHT) * 4;
    const int offset_row_b = (get_global_id(0) % MULT_TRANSPOSE1XW_WIDTH) * 8;

    // src_addr_a = address of matrix A
    // src_addr_b = address of matrix B
    int src0_addr_in_bytes = z * src0_stride_z + y * src0_stride_y + src0_offset_first_element_in_bytes;
    int src1_addr_in_bytes = x * src1_stride_y + src1_offset_first_element_in_bytes;

#if defined(MATRIX_B_DEPTH)
    // Do not slide matrix B if the matrix B has 3 dimensions and matrix A more than 3
    src1_addr_in_bytes += (z % MATRIX_B_DEPTH) * src1_stride_z;
#else  // defined(MATRIX_B_DEPTH)
    src1_addr_in_bytes += z * src1_stride_z;
#endif // defined(MATRIX_B_DEPTH)

    __global short *src_addr_a = (__global short *)(src0_ptr + src0_addr_in_bytes);
    __global short *src_addr_b = (__global short *)(src1_ptr + src1_addr_in_bytes);

    // Compute end row address for matrix B
    __global short *src_end_addr_b = src_addr_b + COLS_B;

    src_addr_a += offset_row_a;
    src_addr_b += offset_row_b;

    // Reset accumulators
    int8 c00 = 0.0f;
    int8 c10 = 0.0f;
    int8 c20 = 0.0f;
    int8 c30 = 0.0f;

    // This for loop performs 1 accumulation for each iteration
    for(; src_addr_b < src_end_addr_b; src_addr_a += 4 * MULT_INTERLEAVE4X4_HEIGHT, src_addr_b += 8 * MULT_TRANSPOSE1XW_WIDTH)
    {
        /* Load values from matrix A (interleaved) and matrix B (transposed) */
        short4 a0 = vload4(0, src_addr_a);
        short8 b0 = vload8(0, src_addr_b);

        c00 = mlal_sat_qs16x8(c00, (short8)a0.s0, b0, FIXED_POINT_POSITION);
        c10 = mlal_sat_qs16x8(c10, (short8)a0.s1, b0, FIXED_POINT_POSITION);
        c20 = mlal_sat_qs16x8(c20, (short8)a0.s2, b0, FIXED_POINT_POSITION);
        c30 = mlal_sat_qs16x8(c30, (short8)a0.s3, b0, FIXED_POINT_POSITION);
    }

    // Compute destination address
    Image dst = CONVERT_TO_IMAGE_STRUCT(dst);

    // Multiply by the weight of matrix product
    short8 c00_qs16 = convert_short8_sat(c00);
    short8 c10_qs16 = convert_short8_sat(c10);
    short8 c20_qs16 = convert_short8_sat(c20);
    short8 c30_qs16 = convert_short8_sat(c30);

#if defined(ALPHA)
    c00_qs16 = mul_sat_qs16x8(c00_qs16, (short8)ALPHA, FIXED_POINT_POSITION);
    c10_qs16 = mul_sat_qs16x8(c10_qs16, (short8)ALPHA, FIXED_POINT_POSITION);
    c20_qs16 = mul_sat_qs16x8(c20_qs16, (short8)ALPHA, FIXED_POINT_POSITION);
    c30_qs16 = mul_sat_qs16x8(c30_qs16, (short8)ALPHA, FIXED_POINT_POSITION);
#endif // defined(ALPHA)

    // Compute dst address
    __global uchar *dst_addr = offset(&dst, 0, 0);

    // Add offset for batched GEMM
    dst_addr += z * dst_stride_z;

    // Store 8x4 block
    vstore8(c00_qs16, 0, (__global short *)(dst_addr + 0 * dst_stride_y));
    vstore8(c10_qs16, 0, (__global short *)(dst_addr + 1 * dst_stride_y));
    vstore8(c20_qs16, 0, (__global short *)(dst_addr + 2 * dst_stride_y));
    vstore8(c30_qs16, 0, (__global short *)(dst_addr + 3 * dst_stride_y));
}
#endif // defined(FIXED_POINT_POSITION)
#endif // defined(COLS_B) && defined(MULT_TRANSPOSE1XW_WIDTH) && defined(MULT_INTERLEAVE4X4_HEIGHT)

#if defined(COLS_A) && defined(NUM_ELEMS_PROCESSED_PER_THREAD_X) && (NUM_ELEMS_PROCESSED_PER_THREAD_Y)
#if defined(DATA_TYPE)
#define VECTOR_TYPE VEC_DATA_TYPE(DATA_TYPE, NUM_ELEMS_PROCESSED_PER_THREAD_X)
/** This OpenCL kernel computes the matrix by matrix multiplication between the matrix A (src0) and matrix B (src1) in case both matrices have not been reshaped
 *
 * @note This OpenCL kernel works with floating point data types (F16/F32)
 * @note The floating point data type must be passed at compile time using -DDATA_TYPE (e.g. -DDATA_TYPE=float)
 * @note The number of elements processed along the x and y directions must be passed at compile time using -DNUM_ELEMS_PROCESSED_PER_THREAD_X and -DNUM_ELEMS_PROCESSED_PER_THREAD_Y
 * @note The number of matrix A columns and the optional alpha's value need to be passed at compile time using -DCOLS_A and -DALPHA
 * @note In case the matrix B has 3 dimensions and the matrix A more than 3, in order to avoid out-of-bounds reads, the number of channels of matrix B must be passed at compile time using MATRIX_B_DEPTH (i.e. -DMATRIX_B_DEPTH=16)
 *       This case can happen when GEMM is used to perform the element-wise multiplication through a batched matrix multiplication (2D Winograd) and we have multiple inputs (i.e. a = [K, M, 16, Batches], b = [N, K, 16])
 *
 * @param[in]  src0_ptr                           Pointer to the source matrix. Supported data types: F16/F32
 * @param[in]  src0_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src0_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src0_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src0_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src0_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[in]  src1_ptr                           Pointer to the source matrix. Supported data types: same as @p src0_ptr
 * @param[in]  src1_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src1_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src1_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src1_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src1_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[out] dst_ptr                            Pointer to the destination matrix Supported data types: same as @p src0_ptr
 * @param[in]  dst_stride_x                       Stride of the destination matrix in X dimension (in bytes)
 * @param[in]  dst_step_x                         dst_gx_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  dst_stride_y                       Stride of the destination matrix in Y dimension (in bytes)
 * @param[in]  dst_step_y                         dst_gx_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  dst_offset_first_element_in_bytes  The offset of the first element in the destination matrix
 */
__kernel void gemm_mm_floating_point(IMAGE_DECLARATION(src0),
                                     IMAGE_DECLARATION(src1),
                                     IMAGE_DECLARATION(dst),
                                     uint src0_stride_z,
                                     uint src1_stride_z,
                                     uint dst_stride_z)
{
    int idx = get_global_id(0) * NUM_ELEMS_PROCESSED_PER_THREAD_X;

    // Compute starting address for matrix A and Matrix B
    int2 src_addr = ((int2)(src0_offset_first_element_in_bytes, src1_offset_first_element_in_bytes));

    // Update address for the matrix A
    src_addr.s0 += get_global_id(1) * src0_stride_y * NUM_ELEMS_PROCESSED_PER_THREAD_Y;

    // Update address for the matrix B
    src_addr.s1 += idx * sizeof(DATA_TYPE);

    // Add offset for batched GEMM
    src_addr.s0 += get_global_id(2) * src0_stride_z;

#if defined(MATRIX_B_DEPTH)
    // Do not slide matrix B if the matrix B has 3 dimensions and matrix A more than 3
    src_addr.s1 += (get_global_id(2) % MATRIX_B_DEPTH) * src1_stride_z;
#else  // defined(MATRIX_B_DEPTH)
    src_addr.s1 += get_global_id(2) * src1_stride_z;
#endif // defined(MATRIX_B_DEPTH)

    int end_row_vec_a = src_addr.s0 + (COLS_A * sizeof(DATA_TYPE));

    VECTOR_TYPE acc0 = 0.0f;
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
    VECTOR_TYPE acc1 = 0.0f;
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
    VECTOR_TYPE acc2 = 0.0f;
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
    VECTOR_TYPE acc3 = 0.0f;
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3

    for(; src_addr.s0 <= (end_row_vec_a - 2 * (int)sizeof(DATA_TYPE)); src_addr += (int2)(2 * sizeof(DATA_TYPE), 2 * src1_stride_y))
    {
        // Load values from matrix A
        VEC_DATA_TYPE(DATA_TYPE, 2)
        a0 = vload2(0, (__global DATA_TYPE *)(src0_ptr + src_addr.s0 + 0 * src0_stride_y));
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
        VEC_DATA_TYPE(DATA_TYPE, 2)
        a1 = vload2(0, (__global DATA_TYPE *)(src0_ptr + src_addr.s0 + 1 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
        VEC_DATA_TYPE(DATA_TYPE, 2)
        a2 = vload2(0, (__global DATA_TYPE *)(src0_ptr + src_addr.s0 + 2 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        VEC_DATA_TYPE(DATA_TYPE, 2)
        a3 = vload2(0, (__global DATA_TYPE *)(src0_ptr + src_addr.s0 + 3 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        // Load values from matrix B
        VECTOR_TYPE b0 = VLOAD(NUM_ELEMS_PROCESSED_PER_THREAD_X)(0, (__global DATA_TYPE *)(src1_ptr + src_addr.s1));
        VECTOR_TYPE b1 = VLOAD(NUM_ELEMS_PROCESSED_PER_THREAD_X)(0, (__global DATA_TYPE *)(src1_ptr + src_addr.s1 + src1_stride_y));

        // Accumulate
        acc0 += b0 * (VECTOR_TYPE)a0.s0;
        acc0 += b1 * (VECTOR_TYPE)a0.s1;
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
        acc1 += b0 * (VECTOR_TYPE)a1.s0;
        acc1 += b1 * (VECTOR_TYPE)a1.s1;
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
        acc2 += b0 * (VECTOR_TYPE)a2.s0;
        acc2 += b1 * (VECTOR_TYPE)a2.s1;
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        acc3 += b0 * (VECTOR_TYPE)a3.s0;
        acc3 += b1 * (VECTOR_TYPE)a3.s1;
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
    }

    for(; src_addr.s0 < end_row_vec_a; src_addr += (int2)(sizeof(DATA_TYPE), src1_stride_y))
    {
        // Load values from matrix A
        DATA_TYPE a0 = *((__global DATA_TYPE *)(src0_ptr + src_addr.s0 + 0 * src0_stride_y));
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
        DATA_TYPE a1 = *((__global DATA_TYPE *)(src0_ptr + src_addr.s0 + 1 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
        DATA_TYPE a2 = *((__global DATA_TYPE *)(src0_ptr + src_addr.s0 + 2 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        DATA_TYPE a3 = *((__global DATA_TYPE *)(src0_ptr + src_addr.s0 + 3 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        // Load values from matrix B
        VECTOR_TYPE b0 = VLOAD(NUM_ELEMS_PROCESSED_PER_THREAD_X)(0, (__global DATA_TYPE *)(src1_ptr + src_addr.s1));

        // Accumulate
        acc0 += b0 * (VECTOR_TYPE)a0;
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
        acc1 += b0 * (VECTOR_TYPE)a1;
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
        acc2 += b0 * (VECTOR_TYPE)a2;
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        acc3 += b0 * (VECTOR_TYPE)a3;
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
    }

    // Compute destination address
    Image dst = CONVERT_TO_IMAGE_STRUCT(dst);

    // Compute dst address
    __global uchar *dst_addr = offset(&dst, 0, 0);

    // Add offset for batched GEMM
    dst_addr += get_global_id(2) * dst_stride_z;

    // Multiply by the weight of matrix-matrix product and store the result
#if defined(ALPHA)
    acc0 = acc0 * (VECTOR_TYPE)ALPHA;
#endif // defined(ALPHA)
    VSTORE(NUM_ELEMS_PROCESSED_PER_THREAD_X)
    (acc0, 0, (__global DATA_TYPE *)(dst_addr + 0 * dst_stride_y));
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if defined(ALPHA)
    acc1 = acc1 * (VECTOR_TYPE)ALPHA;
#endif // defined(ALPHA)
    VSTORE(NUM_ELEMS_PROCESSED_PER_THREAD_X)
    (acc1, 0, (__global DATA_TYPE *)(dst_addr + 1 * dst_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if defined(ALPHA)
    acc2 = acc2 * (VECTOR_TYPE)ALPHA;
#endif // defined(ALPHA)
    VSTORE(NUM_ELEMS_PROCESSED_PER_THREAD_X)
    (acc2, 0, (__global DATA_TYPE *)(dst_addr + 2 * dst_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
#if defined(ALPHA)
    acc3 = acc3 * (VECTOR_TYPE)ALPHA;
#endif // defined(ALPHA)
    VSTORE(NUM_ELEMS_PROCESSED_PER_THREAD_X)
    (acc3, 0, (__global DATA_TYPE *)(dst_addr + 3 * dst_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
}
#endif // defined(DATA_TYPE)

/** This OpenCL kernel computes the matrix by matrix multiplication between the matrix A (src0) and matrix B (src1) in case both matrices have not been reshaped
 *
 * @note This OpenCL kernel works with the 32-bit floating point data type (float) and uses the fma units.
 * @note The number of elements processed along the x and y directions must be passed at compile time using -DNUM_ELEMS_PROCESSED_PER_THREAD_X and -DNUM_ELEMS_PROCESSED_PER_THREAD_Y.
 * This kernel optimally uses -DNUM_ELEMS_PROCESSED_PER_THREAD_X=4.
 * @note The number of matrix A columns must be passed at compile time using -DCOLS_A.
 * @note The optional value of scalar alpha is passed at compile time using -DALPHA=alpha
 * @note In case the matrix B has 3 dimensions and the matrix A more than 3, in order to avoid out-of-bounds reads, the number of channels of matrix B must be passed at compile time using MATRIX_B_DEPTH (i.e. -DMATRIX_B_DEPTH=16)
 *       This case can happen when GEMM is used to perform the element-wise multiplication through a batched matrix multiplication (2D Winograd) and we have multiple inputs (i.e. a = [K, M, 16, Batches], b = [N, K, 16])
 *
 * @param[in]  src0_ptr                           Pointer to the source matrix. Supported data types: F16/F32
 * @param[in]  src0_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src0_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src0_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src0_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src0_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[in]  src1_ptr                           Pointer to the source matrix. Supported data types: same as @p src0_ptr
 * @param[in]  src1_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src1_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src1_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src1_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src1_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[out] dst_ptr                            Pointer to the destination matrix Supported data types: same as @p src0_ptr
 * @param[in]  dst_stride_x                       Stride of the destination matrix in X dimension (in bytes)
 * @param[in]  dst_step_x                         dst_gx_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  dst_stride_y                       Stride of the destination matrix in Y dimension (in bytes)
 * @param[in]  dst_step_y                         dst_gx_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  dst_offset_first_element_in_bytes  The offset of the first element in the destination matrix
 */
__kernel void gemm_mm_floating_point_f32_bifrost(IMAGE_DECLARATION(src0),
                                                 IMAGE_DECLARATION(src1),
                                                 IMAGE_DECLARATION(dst),
                                                 uint src0_stride_z,
                                                 uint src1_stride_z,
                                                 uint dst_stride_z)
{
    int idx = get_global_id(0) * NUM_ELEMS_PROCESSED_PER_THREAD_X;

    // Compute starting address for matrix A and matrix B
    int2 src_addr = ((int2)(src0_offset_first_element_in_bytes, src1_offset_first_element_in_bytes));

    // Update address for matrix A
    src_addr.s0 += get_global_id(1) * src0_stride_y * NUM_ELEMS_PROCESSED_PER_THREAD_Y;

    // Update address for matrix B
    src_addr.s1 += idx * sizeof(float);

    // Add offset for batched GEMM
    src_addr.s0 += get_global_id(2) * src0_stride_z;

#if defined(MATRIX_B_DEPTH)
    // Do not slide matrix B if the matrix B has 3 dimensions and matrix A more than 3
    src_addr.s1 += (get_global_id(2) % MATRIX_B_DEPTH) * src1_stride_z;
#else  // defined(MATRIX_B_DEPTH)
    src_addr.s1 += get_global_id(2) * src1_stride_z;
#endif // defined(MATRIX_B_DEPTH)

    // Initialize accumulators
    float acc00 = 0.0f;
    float acc01 = 0.0f;
    float acc02 = 0.0f;
    float acc03 = 0.0f;

#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
    float acc10 = 0.0f;
    float acc11 = 0.0f;
    float acc12 = 0.0f;
    float acc13 = 0.0f;
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1

#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
    float acc20 = 0.0f;
    float acc21 = 0.0f;
    float acc22 = 0.0f;
    float acc23 = 0.0f;
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2

#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
    float acc30 = 0.0f;
    float acc31 = 0.0f;
    float acc32 = 0.0f;
    float acc33 = 0.0f;
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3

    // A and B src indices get incremented at the same time.
    int i = 0;
    for(; i <= ((int)COLS_A - 4); i += 4)
    {
        // Load values from matrix A and matrix B
        float4 a0 = vload4(0, (__global float *)(src0_ptr + src_addr.s0 + 0 * src0_stride_y));
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
        float4 a1 = vload4(0, (__global float *)(src0_ptr + src_addr.s0 + 1 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
        float4 a2 = vload4(0, (__global float *)(src0_ptr + src_addr.s0 + 2 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        float4 a3 = vload4(0, (__global float *)(src0_ptr + src_addr.s0 + 3 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        float4 b0 = vload4(0, (__global float *)(src1_ptr + src_addr.s1));
        src_addr.s1 += src1_stride_y;

        // Multiply and accumulate
        acc00 = fma(a0.s0, b0.s0, acc00);
        acc01 = fma(a0.s0, b0.s1, acc01);
        acc02 = fma(a0.s0, b0.s2, acc02);
        acc03 = fma(a0.s0, b0.s3, acc03);

#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1

        acc10 = fma(a1.s0, b0.s0, acc10);
        acc11 = fma(a1.s0, b0.s1, acc11);
        acc12 = fma(a1.s0, b0.s2, acc12);
        acc13 = fma(a1.s0, b0.s3, acc13);

#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2

        acc20 = fma(a2.s0, b0.s0, acc20);
        acc21 = fma(a2.s0, b0.s1, acc21);
        acc22 = fma(a2.s0, b0.s2, acc22);
        acc23 = fma(a2.s0, b0.s3, acc23);

#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3

        acc30 = fma(a3.s0, b0.s0, acc30);
        acc31 = fma(a3.s0, b0.s1, acc31);
        acc32 = fma(a3.s0, b0.s2, acc32);
        acc33 = fma(a3.s0, b0.s3, acc33);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3

        // Load values from matrix A and matrix B
        b0 = vload4(0, (__global float *)(src1_ptr + src_addr.s1));
        src_addr.s1 += src1_stride_y;

        // Multiply and accumulate
        acc00 = fma(a0.s1, b0.s0, acc00);
        acc01 = fma(a0.s1, b0.s1, acc01);
        acc02 = fma(a0.s1, b0.s2, acc02);
        acc03 = fma(a0.s1, b0.s3, acc03);

#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1

        acc10 = fma(a1.s1, b0.s0, acc10);
        acc11 = fma(a1.s1, b0.s1, acc11);
        acc12 = fma(a1.s1, b0.s2, acc12);
        acc13 = fma(a1.s1, b0.s3, acc13);

#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2

        acc20 = fma(a2.s1, b0.s0, acc20);
        acc21 = fma(a2.s1, b0.s1, acc21);
        acc22 = fma(a2.s1, b0.s2, acc22);
        acc23 = fma(a2.s1, b0.s3, acc23);

#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3

        acc30 = fma(a3.s1, b0.s0, acc30);
        acc31 = fma(a3.s1, b0.s1, acc31);
        acc32 = fma(a3.s1, b0.s2, acc32);
        acc33 = fma(a3.s1, b0.s3, acc33);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3

        // Load values from matrix A and matrix B
        b0 = vload4(0, (__global float *)(src1_ptr + src_addr.s1));
        src_addr.s1 += src1_stride_y;

        // Multiply and accumulate
        acc00 = fma(a0.s2, b0.s0, acc00);
        acc01 = fma(a0.s2, b0.s1, acc01);
        acc02 = fma(a0.s2, b0.s2, acc02);
        acc03 = fma(a0.s2, b0.s3, acc03);

#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1

        acc10 = fma(a1.s2, b0.s0, acc10);
        acc11 = fma(a1.s2, b0.s1, acc11);
        acc12 = fma(a1.s2, b0.s2, acc12);
        acc13 = fma(a1.s2, b0.s3, acc13);

#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2

        acc20 = fma(a2.s2, b0.s0, acc20);
        acc21 = fma(a2.s2, b0.s1, acc21);
        acc22 = fma(a2.s2, b0.s2, acc22);
        acc23 = fma(a2.s2, b0.s3, acc23);

#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3

        acc30 = fma(a3.s2, b0.s0, acc30);
        acc31 = fma(a3.s2, b0.s1, acc31);
        acc32 = fma(a3.s2, b0.s2, acc32);
        acc33 = fma(a3.s2, b0.s3, acc33);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3

        // Load values from matrix A and matrix B
        b0 = vload4(0, (__global float *)(src1_ptr + src_addr.s1));
        src_addr.s1 += src1_stride_y;

        // Multiply and accumulate
        acc00 = fma(a0.s3, b0.s0, acc00);
        acc01 = fma(a0.s3, b0.s1, acc01);
        acc02 = fma(a0.s3, b0.s2, acc02);
        acc03 = fma(a0.s3, b0.s3, acc03);

#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1

        acc10 = fma(a1.s3, b0.s0, acc10);
        acc11 = fma(a1.s3, b0.s1, acc11);
        acc12 = fma(a1.s3, b0.s2, acc12);
        acc13 = fma(a1.s3, b0.s3, acc13);

#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2

        acc20 = fma(a2.s3, b0.s0, acc20);
        acc21 = fma(a2.s3, b0.s1, acc21);
        acc22 = fma(a2.s3, b0.s2, acc22);
        acc23 = fma(a2.s3, b0.s3, acc23);

#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3

        acc30 = fma(a3.s3, b0.s0, acc30);
        acc31 = fma(a3.s3, b0.s1, acc31);
        acc32 = fma(a3.s3, b0.s2, acc32);
        acc33 = fma(a3.s3, b0.s3, acc33);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3

        src_addr.s0 += 4 * sizeof(float);
    }

    for(; i < (int)COLS_A; ++i)
    {
        // Load values from matrix A
        float a0 = *((__global float *)(src0_ptr + src_addr.s0));
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
        float a1 = *((__global float *)(src0_ptr + src_addr.s0 + 1 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
        float a2 = *((__global float *)(src0_ptr + src_addr.s0 + 2 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        float a3 = *((__global float *)(src0_ptr + src_addr.s0 + 3 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        // Load values from matrix B
        float4 b0 = vload4(0, (__global float *)(src1_ptr + src_addr.s1));
        src_addr.s1 += src1_stride_y;

        // Multiply and accumulate
        acc00 = fma(a0, b0.s0, acc00);
        acc01 = fma(a0, b0.s1, acc01);
        acc02 = fma(a0, b0.s2, acc02);
        acc03 = fma(a0, b0.s3, acc03);
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
        acc10 = fma(a1, b0.s0, acc10);
        acc11 = fma(a1, b0.s1, acc11);
        acc12 = fma(a1, b0.s2, acc12);
        acc13 = fma(a1, b0.s3, acc13);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
        acc20 = fma(a2, b0.s0, acc20);
        acc21 = fma(a2, b0.s1, acc21);
        acc22 = fma(a2, b0.s2, acc22);
        acc23 = fma(a2, b0.s3, acc23);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        acc30 = fma(a3, b0.s0, acc30);
        acc31 = fma(a3, b0.s1, acc31);
        acc32 = fma(a3, b0.s2, acc32);
        acc33 = fma(a3, b0.s3, acc33);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3

        src_addr.s0 += sizeof(float);
    }

    // Compute destination address
    Image dst = CONVERT_TO_IMAGE_STRUCT(dst);

    // Multiply by the weight of matrix-matrix product and store the result
#if defined(ALPHA)
    acc00 = acc00 * ALPHA;
    acc01 = acc01 * ALPHA;
    acc02 = acc02 * ALPHA;
    acc03 = acc03 * ALPHA;
#endif // defined(ALPHA)

    // Compute dst address
    __global uchar *dst_addr = offset(&dst, 0, 0);

    // Add offset for batched GEMM
    dst_addr += get_global_id(2) * dst_stride_z;

    float4 acc0 = ((float4)(acc00, acc01, acc02, acc03));
    vstore4(acc0, 0, (__global float *)(dst_addr + 0 * dst_stride_y));

#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if defined(ALPHA)
    acc10 = acc10 * ALPHA;
    acc11 = acc11 * ALPHA;
    acc12 = acc12 * ALPHA;
    acc13 = acc13 * ALPHA;
#endif // defined(ALPHA)
    float4 acc1 = ((float4)(acc10, acc11, acc12, acc13));
    vstore4(acc1, 0, (__global float *)(dst_addr + 1 * dst_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if defined(ALPHA)
    acc20 = acc20 * ALPHA;
    acc21 = acc21 * ALPHA;
    acc22 = acc22 * ALPHA;
    acc23 = acc23 * ALPHA;
#endif // defined(ALPHA)
    float4 acc2 = ((float4)(acc20, acc21, acc22, acc23));
    vstore4(acc2, 0, (__global float *)(dst_addr + 2 * dst_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
#if defined(ALPHA)
    acc30 = acc30 * ALPHA;
    acc31 = acc31 * ALPHA;
    acc32 = acc32 * ALPHA;
    acc33 = acc33 * ALPHA;
#endif // defined(ALPHA)
    float4 acc3 = ((float4)(acc30, acc31, acc32, acc33));
    vstore4(acc3, 0, (__global float *)(dst_addr + 3 * dst_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
}

/** This OpenCL kernel computes the matrix by matrix multiplication between the matrix A (src0) and matrix B (src1) in case both matrices have not been reshaped
 *
 * @note This OpenCL kernel works with the 32-bit floating point data type (float) and uses the fma units.
 * This OpenCL kernel is optimized for Bifrost when the number of matrix B columns is less or equal to 1000.
 * @note The number of elements processed along the x and y directions must be passed at compile time using -DNUM_ELEMS_PROCESSED_PER_THREAD_X and -DNUM_ELEMS_PROCESSED_PER_THREAD_Y.
 * This kernel optimally uses -DNUM_ELEMS_PROCESSED_PER_THREAD_X=2.
 * @note The number of matrix A columns must be passed at compile time using -DCOLS_A.
 * @note The optional value of scalar alpha is passed at compile time using -DALPHA=alpha if alpha!=1.0f.
 * @note In case the matrix B has 3 dimensions and the matrix A more than 3, in order to avoid out-of-bounds reads, the number of channels of matrix B must be passed at compile time using MATRIX_B_DEPTH (i.e. -DMATRIX_B_DEPTH=16)
 *       This case can happen when GEMM is used to perform the element-wise multiplication through a batched matrix multiplication (2D Winograd) and we have multiple inputs (i.e. a = [K, M, 16, Batches], b = [N, K, 16])
 *
 * @param[in]  src0_ptr                           Pointer to the source matrix. Supported data types: F16/F32
 * @param[in]  src0_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src0_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src0_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src0_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src0_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[in]  src1_ptr                           Pointer to the source matrix. Supported data types: same as @p src0_ptr
 * @param[in]  src1_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src1_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src1_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src1_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src1_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[out] dst_ptr                            Pointer to the destination matrix Supported data types: same as @p src0_ptr
 * @param[in]  dst_stride_x                       Stride of the destination matrix in X dimension (in bytes)
 * @param[in]  dst_step_x                         dst_gx_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  dst_stride_y                       Stride of the destination matrix in Y dimension (in bytes)
 * @param[in]  dst_step_y                         dst_gx_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  dst_offset_first_element_in_bytes  The offset of the first element in the destination matrix
 */
__kernel void gemm_mm_floating_point_f32_bifrost_1000(IMAGE_DECLARATION(src0),
                                                      IMAGE_DECLARATION(src1),
                                                      IMAGE_DECLARATION(dst),
                                                      uint src0_stride_z,
                                                      uint src1_stride_z,
                                                      uint dst_stride_z)
{
    // Requires 2 NUM_ELEMS_PROCESSED_PER_THREAD_X, C vect2, A vect4, B (2 vload2) // to fix for NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
    int idx = get_global_id(0) * NUM_ELEMS_PROCESSED_PER_THREAD_X;

    // Compute starting address for matrix A and Matrix B
    int2 src_addr = ((int2)(src0_offset_first_element_in_bytes, src1_offset_first_element_in_bytes));

    // Update address for the matrix A
    src_addr.s0 += get_global_id(1) * src0_stride_y * NUM_ELEMS_PROCESSED_PER_THREAD_Y;

    // Update address for the matrix B
    src_addr.s1 += idx * sizeof(float);

    // Add offset for batched GEMM
    src_addr.s0 += get_global_id(2) * src0_stride_z;

#if defined(MATRIX_B_DEPTH)
    // Do not slide matrix B if the matrix B has 3 dimensions and matrix A more than 3
    src_addr.s1 += (get_global_id(2) % MATRIX_B_DEPTH) * src1_stride_z;
#else  // defined(MATRIX_B_DEPTH)
    src_addr.s1 += get_global_id(2) * src1_stride_z;
#endif // defined(MATRIX_B_DEPTH)

    // Initialize accumulators
    float acc00 = 0.0f;
    float acc01 = 0.0f;

#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
    float acc10 = 0.0f;
    float acc11 = 0.0f;
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
    float acc20 = 0.0f;
    float acc21 = 0.0f;
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
    float acc30 = 0.0f;
    float acc31 = 0.0f;
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3

    // A and B src indices get incremented at the same time.
    int i = 0;
    for(; i <= ((int)COLS_A - 8); i += 8)
    {
        // Load values from matrix A
        float8 a0 = vload8(0, (__global float *)(src0_ptr + src_addr.s0));

        // Load values from matrix B
        float2 b0 = vload2(0, (__global float *)(src1_ptr + src_addr.s1));
        src_addr.s1 += src1_stride_y;
        float2 b1 = vload2(0, (__global float *)(src1_ptr + src_addr.s1));
        src_addr.s1 += src1_stride_y;
        float2 b2 = vload2(0, (__global float *)(src1_ptr + src_addr.s1));
        src_addr.s1 += src1_stride_y;
        float2 b3 = vload2(0, (__global float *)(src1_ptr + src_addr.s1));
        src_addr.s1 += src1_stride_y;
        float2 b4 = vload2(0, (__global float *)(src1_ptr + src_addr.s1));
        src_addr.s1 += src1_stride_y;
        float2 b5 = vload2(0, (__global float *)(src1_ptr + src_addr.s1));
        src_addr.s1 += src1_stride_y;
        float2 b6 = vload2(0, (__global float *)(src1_ptr + src_addr.s1));
        src_addr.s1 += src1_stride_y;
        float2 b7 = vload2(0, (__global float *)(src1_ptr + src_addr.s1));
        src_addr.s1 += src1_stride_y;

        // Multiply and accumulate
        acc00 = fma(a0.s0, b0.s0, acc00);
        acc00 = fma(a0.s1, b1.s0, acc00);
        acc00 = fma(a0.s2, b2.s0, acc00);
        acc00 = fma(a0.s3, b3.s0, acc00);
        acc00 = fma(a0.s4, b4.s0, acc00);
        acc00 = fma(a0.s5, b5.s0, acc00);
        acc00 = fma(a0.s6, b6.s0, acc00);
        acc00 = fma(a0.s7, b7.s0, acc00);

        acc01 = fma(a0.s0, b0.s1, acc01);
        acc01 = fma(a0.s1, b1.s1, acc01);
        acc01 = fma(a0.s2, b2.s1, acc01);
        acc01 = fma(a0.s3, b3.s1, acc01);
        acc01 = fma(a0.s4, b4.s1, acc01);
        acc01 = fma(a0.s5, b5.s1, acc01);
        acc01 = fma(a0.s6, b6.s1, acc01);
        acc01 = fma(a0.s7, b7.s1, acc01);

#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
        a0    = vload8(0, (__global float *)(src0_ptr + src_addr.s0 + 1 * src0_stride_y));
        acc10 = fma(a0.s0, b0.s0, acc10);
        acc10 = fma(a0.s1, b1.s0, acc10);
        acc10 = fma(a0.s2, b2.s0, acc10);
        acc10 = fma(a0.s3, b3.s0, acc10);
        acc10 = fma(a0.s4, b4.s0, acc10);
        acc10 = fma(a0.s5, b5.s0, acc10);
        acc10 = fma(a0.s6, b6.s0, acc10);
        acc10 = fma(a0.s7, b7.s0, acc10);

        acc11 = fma(a0.s0, b0.s1, acc11);
        acc11 = fma(a0.s1, b1.s1, acc11);
        acc11 = fma(a0.s2, b2.s1, acc11);
        acc11 = fma(a0.s3, b3.s1, acc11);
        acc11 = fma(a0.s4, b4.s1, acc11);
        acc11 = fma(a0.s5, b5.s1, acc11);
        acc11 = fma(a0.s6, b6.s1, acc11);
        acc11 = fma(a0.s7, b7.s1, acc11);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
        a0    = vload8(0, (__global float *)(src0_ptr + src_addr.s0 + 2 * src0_stride_y));
        acc20 = fma(a0.s0, b0.s0, acc20);
        acc20 = fma(a0.s1, b1.s0, acc20);
        acc20 = fma(a0.s2, b2.s0, acc20);
        acc20 = fma(a0.s3, b3.s0, acc20);
        acc20 = fma(a0.s4, b4.s0, acc20);
        acc20 = fma(a0.s5, b5.s0, acc20);
        acc20 = fma(a0.s6, b6.s0, acc20);
        acc20 = fma(a0.s7, b7.s0, acc20);

        acc21 = fma(a0.s0, b0.s1, acc21);
        acc21 = fma(a0.s1, b1.s1, acc21);
        acc21 = fma(a0.s2, b2.s1, acc21);
        acc21 = fma(a0.s3, b3.s1, acc21);
        acc21 = fma(a0.s4, b4.s1, acc21);
        acc21 = fma(a0.s5, b5.s1, acc21);
        acc21 = fma(a0.s6, b6.s1, acc21);
        acc21 = fma(a0.s7, b7.s1, acc21);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        a0    = vload8(0, (__global float *)(src0_ptr + src_addr.s0 + 3 * src0_stride_y));
        acc30 = fma(a0.s0, b0.s0, acc30);
        acc30 = fma(a0.s1, b1.s0, acc30);
        acc30 = fma(a0.s2, b2.s0, acc30);
        acc30 = fma(a0.s3, b3.s0, acc30);
        acc30 = fma(a0.s4, b4.s0, acc30);
        acc30 = fma(a0.s5, b5.s0, acc30);
        acc30 = fma(a0.s6, b6.s0, acc30);
        acc30 = fma(a0.s7, b7.s0, acc30);

        acc31 = fma(a0.s0, b0.s1, acc31);
        acc31 = fma(a0.s1, b1.s1, acc31);
        acc31 = fma(a0.s2, b2.s1, acc31);
        acc31 = fma(a0.s3, b3.s1, acc31);
        acc31 = fma(a0.s4, b4.s1, acc31);
        acc31 = fma(a0.s5, b5.s1, acc31);
        acc31 = fma(a0.s6, b6.s1, acc31);
        acc31 = fma(a0.s7, b7.s1, acc31);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3

        src_addr.s0 += sizeof(float) * 8;
    }
    // float size increment
    for(; i < (int)COLS_A; ++i)
    {
        // Load values from matrix A
        float a0 = *((__global float *)(src0_ptr + src_addr.s0 + 0 * src0_stride_y));
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
        float a1 = *((__global float *)(src0_ptr + src_addr.s0 + 1 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
        float a2 = *((__global float *)(src0_ptr + src_addr.s0 + 2 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        float a3 = *((__global float *)(src0_ptr + src_addr.s0 + 3 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        // Load values from matrix B
        float2 b0 = vload2(0, (__global float *)(src1_ptr + src_addr.s1));
        src_addr.s1 += src1_stride_y;

        // Multiply and accumulate
        acc00 = fma(a0, b0.s0, acc00);
        acc01 = fma(a0, b0.s1, acc01);
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
        acc10 = fma(a1, b0.s0, acc10);
        acc11 = fma(a1, b0.s1, acc11);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
        acc20 = fma(a2, b0.s0, acc20);
        acc21 = fma(a2, b0.s1, acc21);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        acc30 = fma(a3, b0.s0, acc30);
        acc31 = fma(a3, b0.s1, acc31);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3

        src_addr.s0 += sizeof(float);
    }

    // Compute destination address
    Image dst = CONVERT_TO_IMAGE_STRUCT(dst);

    // Compute dst address
    __global uchar *dst_addr = offset(&dst, 0, 0);

    // Add offset for batched GEMM
    dst_addr += get_global_id(2) * dst_stride_z;

    // Multiply by the weight of matrix-matrix product and store the result
#if defined(ALPHA)
    acc00 = acc00 * ALPHA;
    acc01 = acc01 * ALPHA;
#endif // defined(ALPHA)
    float2 acc0 = ((float2)(acc00, acc01));
    vstore2(acc0, 0, (__global float *)(dst_addr + 0 * dst_stride_y));
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if defined(ALPHA)
    acc10 = acc10 * ALPHA;
    acc11 = acc11 * ALPHA;
#endif // defined(ALPHA)
    float2 acc1 = ((float2)(acc10, acc11));
    vstore2(acc1, 0, (__global float *)(dst_addr + 1 * dst_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if defined(ALPHA)
    acc20 = acc20 * ALPHA;
    acc21 = acc21 * ALPHA;
#endif // defined(ALPHA)
    float2 acc2 = ((float2)(acc20, acc21));
    vstore2(acc2, 0, (__global float *)(dst_addr + 2 * dst_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
#if defined(ALPHA)
    acc30 = acc30 * ALPHA;
    acc31 = acc31 * ALPHA;
#endif // defined(ALPHA)
    float2 acc3 = (float2)(acc30, acc31);
    vstore2(acc3, 0, (__global float *)(dst_addr + 3 * dst_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
}

/** This OpenCL kernel computes the matrix by matrix multiplication between the matrix A (src0) and matrix B (src1) in case both matrices have not beed reshaped
 *
 * @note This OpenCL kernel works with the 16-bit floating point data type (half) and uses the fma units.
 * @note The number of elements processed along the x and y directions must be passed at compile time using -DNUM_ELEMS_PROCESSED_PER_THREAD_X and -DNUM_ELEMS_PROCESSED_PER_THREAD_Y.
 * This kernel optimally uses -DNUM_ELEMS_PROCESSED_PER_THREAD_X=4.
 * @note The number of matrix A columns must be passed at compile time using -DCOLS_A.
 * @note The optional value of scalar alpha is passed at compile time using -DALPHA=alpha
 * @note In case the matrix B has 3 dimensions and the matrix A more than 3, in order to avoid out-of-bounds reads, the number of channels of matrix B must be passed at compile time using MATRIX_B_DEPTH (i.e. -DMATRIX_B_DEPTH=16)
 *       This case can happen when GEMM is used to perform the element-wise multiplication through a batched matrix multiplication (2D Winograd) and we have multiple inputs (i.e. a = [K, M, 16, Batches], b = [N, K, 16])
 *
 * @param[in]  src0_ptr                           Pointer to the source matrix. Supported data types: F16
 * @param[in]  src0_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src0_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src0_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src0_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src0_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[in]  src1_ptr                           Pointer to the source matrix. Supported data types: same as @p src0_ptr
 * @param[in]  src1_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src1_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src1_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src1_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src1_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[out] dst_ptr                            Pointer to the destination matrix Supported data types: same as @p src0_ptr
 * @param[in]  dst_stride_x                       Stride of the destination matrix in X dimension (in bytes)
 * @param[in]  dst_step_x                         dst_gx_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  dst_stride_y                       Stride of the destination matrix in Y dimension (in bytes)
 * @param[in]  dst_step_y                         dst_gx_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  dst_offset_first_element_in_bytes  The offset of the first element in the destination matrix
 */
__kernel void gemm_mm_floating_point_f16_bifrost(IMAGE_DECLARATION(src0),
                                                 IMAGE_DECLARATION(src1),
                                                 IMAGE_DECLARATION(dst),
                                                 uint src0_stride_z,
                                                 uint src1_stride_z,
                                                 uint dst_stride_z)
{
    int idx = get_global_id(0) * NUM_ELEMS_PROCESSED_PER_THREAD_X;

    // Compute starting address for matrix A and Matrix B
    int2 src_addr = ((int2)(src0_offset_first_element_in_bytes, src1_offset_first_element_in_bytes));

    // Update address for the matrix A
    src_addr.s0 += get_global_id(1) * src0_stride_y * NUM_ELEMS_PROCESSED_PER_THREAD_Y;

    // Update address for the matrix B
    src_addr.s1 += idx * sizeof(half);

    // Add offset for batched GEMM
    src_addr.s0 += get_global_id(2) * src0_stride_z;

#if defined(MATRIX_B_DEPTH)
    // Do not slide matrix B if the matrix B has 3 dimensions and matrix A more than 3
    src_addr.s1 += (get_global_id(2) % MATRIX_B_DEPTH) * src1_stride_z;
#else  // defined(MATRIX_B_DEPTH)
    src_addr.s1 += get_global_id(2) * src1_stride_z;
#endif // defined(MATRIX_B_DEPTH)

    half8 acc0 = 0.0h;
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
    half8 acc1 = 0.0h;
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
    half8 acc2 = 0.0h;
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
    half8 acc3 = 0.0h;
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3

    int i = 0;
    for(; i <= ((int)COLS_A - 4); i += 4)
    {
        // Load values from matrix A
        half4 a0 = vload4(0, (__global half *)(src0_ptr + src_addr.s0 + 0 * src0_stride_y));
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
        half4 a1 = vload4(0, (__global half *)(src0_ptr + src_addr.s0 + 1 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
        half4 a2 = vload4(0, (__global half *)(src0_ptr + src_addr.s0 + 2 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        half4 a3 = vload4(0, (__global half *)(src0_ptr + src_addr.s0 + 3 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        // Load values from matrix B
        half8 b0 = vload8(0, (__global half *)(src1_ptr + src_addr.s1));
        src_addr.s1 += src1_stride_y;

        // Accumulate
        acc0 = fma(b0, (half8)a0.s0, acc0);
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
        acc1 = fma(b0, (half8)a1.s0, acc1);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
        acc2 = fma(b0, (half8)a2.s0, acc2);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        acc3 = fma(b0, (half8)a3.s0, acc3);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3

        b0 = vload8(0, (__global half *)(src1_ptr + src_addr.s1));
        src_addr.s1 += src1_stride_y;
        acc0 = fma(b0, (half8)a0.s1, acc0);
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
        acc1 = fma(b0, (half8)a1.s1, acc1);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
        acc2 = fma(b0, (half8)a2.s1, acc2);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        acc3 = fma(b0, (half8)a3.s1, acc3);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3

        b0 = vload8(0, (__global half *)(src1_ptr + src_addr.s1));
        src_addr.s1 += src1_stride_y;
        acc0 = fma(b0, (half8)a0.s2, acc0);
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
        acc1 = fma(b0, (half8)a1.s2, acc1);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
        acc2 = fma(b0, (half8)a2.s2, acc2);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        acc3 = fma(b0, (half8)a3.s2, acc3);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3

        b0 = vload8(0, (__global half *)(src1_ptr + src_addr.s1));
        src_addr.s1 += src1_stride_y;
        acc0 = fma(b0, (half8)a0.s3, acc0);
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
        acc1 = fma(b0, (half8)a1.s3, acc1);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
        acc2 = fma(b0, (half8)a2.s3, acc2);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        acc3 = fma(b0, (half8)a3.s3, acc3);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3

        src_addr.s0 += 4 * sizeof(half);
    }

    for(; i < (int)COLS_A; ++i)
    {
        // Load values from matrix A
        half a0 = *((__global half *)(src0_ptr + src_addr.s0 + 0 * src0_stride_y));
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
        half a1 = *((__global half *)(src0_ptr + src_addr.s0 + 1 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
        half a2 = *((__global half *)(src0_ptr + src_addr.s0 + 2 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        half a3 = *((__global half *)(src0_ptr + src_addr.s0 + 3 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        // Load values from matrix B
        half8 b0 = vload8(0, (__global half *)(src1_ptr + src_addr.s1));

        src_addr += (int2)(sizeof(half), src1_stride_y);

        // Accumulate
        acc0 = fma(b0, (half8)a0, acc0); // b0 * (half8)a0;
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
        acc1 = fma(b0, (half8)a1, acc1); // b0 * (half8)a1;
#endif                                   // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
        acc2 = fma(b0, (half8)a2, acc2); // b0 * (half8)a2;
#endif                                   // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        acc3 = fma(b0, (half8)a3, acc3); // b0 * (half8)a3;
#endif                                   // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
    }

    // Compute destination address
    Image dst = CONVERT_TO_IMAGE_STRUCT(dst);

    // Compute dst address
    __global uchar *dst_addr = offset(&dst, 0, 0);

    // Add offset for batched GEMM
    dst_addr += get_global_id(2) * dst_stride_z;

    // Multiply by the weight of matrix-matrix product and store the result
#if defined(ALPHA)
    acc0 = acc0 * (half8)ALPHA;
#endif // defined(ALPHA)
    vstore8(acc0, 0, (__global half *)(dst_addr + 0 * dst_stride_y));
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if defined(ALPHA)
    acc1 = acc1 * (half8)ALPHA;
#endif // defined(ALPHA)
    vstore8(acc1, 0, (__global half *)(dst_addr + 1 * dst_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if defined(ALPHA)
    acc2 = acc2 * (half8)ALPHA;
#endif // defined(ALPHA)
    vstore8(acc2, 0, (__global half *)(dst_addr + 2 * dst_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
#if defined(ALPHA)
    acc3 = acc3 * (half8)ALPHA;
#endif // defined(ALPHA)
    vstore8(acc3, 0, (__global half *)(dst_addr + 3 * dst_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
}

#if defined(FIXED_POINT_POSITION)
/** This OpenCL kernel computes the matrix by matrix multiplication between the matrix A (src0) and matrix B (src1) in case both matrices have not beed reshaped
 *
 * @note This OpenCL kernel works with fixed point data types QS8
 * @note The number of elements processed along the x and y directions must be passed at compile time using -DNUM_ELEMS_PROCESSED_PER_THREAD_X and -DNUM_ELEMS_PROCESSED_PER_THREAD_Y
 * @note The number matrix A columns, the number of elements processed per thread along the Y direction and the alpha's value need to be passed at compile time using -DCOLS_A, -DNUM_ELEMS_PROCESSED_PER_THREAD_Y and -DALPHA
 * @note The fixed point position need to be passed at compile time using -DFIXED_POINT_POSITION
 * @note The optional alpha value must be passed in 8 bit fixed point format using -DALPHA
 * @note In case the matrix B has 3 dimensions and the matrix A more than 3, in order to avoid out-of-bounds reads, the number of channels of matrix B must be passed at compile time using MATRIX_B_DEPTH (i.e. -DMATRIX_B_DEPTH=16)
 *       This case can happen when GEMM is used to perform the element-wise multiplication through a batched matrix multiplication (2D Winograd) and we have multiple inputs (i.e. a = [K, M, 16, Batches], b = [N, K, 16])
 *
 * @param[in]  src0_ptr                           Pointer to the source matrix. Supported data types: QS8/QS16
 * @param[in]  src0_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src0_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src0_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src0_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src0_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[in]  src1_ptr                           Pointer to the source matrix. Supported data types: same as @p src0_ptr
 * @param[in]  src1_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src1_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src1_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src1_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src1_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[out] dst_ptr                            Pointer to the destination matrix Supported data types: same as @p src0_ptr
 * @param[in]  dst_stride_x                       Stride of the destination matrix in X dimension (in bytes)
 * @param[in]  dst_step_x                         dst_gx_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  dst_stride_y                       Stride of the destination matrix in Y dimension (in bytes)
 * @param[in]  dst_step_y                         dst_gx_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  dst_offset_first_element_in_bytes  The offset of the first element in the destination matrix
 */
__kernel void gemm_mm_qs8(IMAGE_DECLARATION(src0),
                          IMAGE_DECLARATION(src1),
                          IMAGE_DECLARATION(dst),
                          uint src0_stride_z,
                          uint src1_stride_z,
                          uint dst_stride_z)
{
    int idx = get_global_id(0) * NUM_ELEMS_PROCESSED_PER_THREAD_X;

    // Compute starting address for matrix A and Matrix B
    int2 src_addr = ((int2)(src0_offset_first_element_in_bytes, src1_offset_first_element_in_bytes));

    // Update address for the matrix A
    src_addr.s0 += get_global_id(1) * src0_stride_y * NUM_ELEMS_PROCESSED_PER_THREAD_Y;

    // Update address for the matrix B
    src_addr.s1 += idx * sizeof(char);

    // Add offset for batched GEMM
    src_addr.s0 += get_global_id(2) * src0_stride_z;

#if defined(MATRIX_B_DEPTH)
    // Do not slide matrix B if the matrix B has 3 dimensions and matrix A more than 3
    src_addr.s1 += (get_global_id(2) % MATRIX_B_DEPTH) * src1_stride_z;
#else  // defined(MATRIX_B_DEPTH)
    src_addr.s1 += get_global_id(2) * src1_stride_z;
#endif // defined(MATRIX_B_DEPTH)

    int end_row_vec_a = src_addr.s0 + (COLS_A * sizeof(char));

    short8 acc00 = 0;
    short8 acc01 = 0;
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
    short8 acc10 = 0;
    short8 acc11 = 0;
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
    short8 acc20 = 0;
    short8 acc21 = 0;
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
    short8 acc30 = 0;
    short8 acc31 = 0;
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3

    // This for loop performs 4 accumulations per iteration
    for(; src_addr.s0 <= (end_row_vec_a - 2); src_addr += (int2)(2, 2 * src1_stride_y))
    {
        char2 a0 = vload2(0, (__global char *)(src0_ptr + src_addr.s0 + 0 * src0_stride_y));
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
        char2 a1 = vload2(0, (__global char *)(src0_ptr + src_addr.s0 + 1 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
        char2 a2 = vload2(0, (__global char *)(src0_ptr + src_addr.s0 + 2 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        char2 a3 = vload2(0, (__global char *)(src0_ptr + src_addr.s0 + 3 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        char16 b0 = vload16(0, (__global char *)(src1_ptr + src_addr.s1 + 0 * src1_stride_y));
        char16 b1 = vload16(0, (__global char *)(src1_ptr + src_addr.s1 + 1 * src1_stride_y));

        acc00 = mlal_sat_qs8x8(acc00, (char8)a0.s0, b0.s01234567, FIXED_POINT_POSITION);
        acc00 = mlal_sat_qs8x8(acc00, (char8)a0.s1, b1.s01234567, FIXED_POINT_POSITION);
        acc01 = mlal_sat_qs8x8(acc01, (char8)a0.s0, b0.s89ABCDEF, FIXED_POINT_POSITION);
        acc01 = mlal_sat_qs8x8(acc01, (char8)a0.s1, b1.s89ABCDEF, FIXED_POINT_POSITION);
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
        acc10 = mlal_sat_qs8x8(acc10, (char8)a1.s0, b0.s01234567, FIXED_POINT_POSITION);
        acc10 = mlal_sat_qs8x8(acc10, (char8)a1.s1, b1.s01234567, FIXED_POINT_POSITION);
        acc11 = mlal_sat_qs8x8(acc11, (char8)a1.s0, b0.s89ABCDEF, FIXED_POINT_POSITION);
        acc11 = mlal_sat_qs8x8(acc11, (char8)a1.s1, b1.s89ABCDEF, FIXED_POINT_POSITION);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
        acc20 = mlal_sat_qs8x8(acc20, (char8)a2.s0, b0.s01234567, FIXED_POINT_POSITION);
        acc20 = mlal_sat_qs8x8(acc20, (char8)a2.s1, b1.s01234567, FIXED_POINT_POSITION);
        acc21 = mlal_sat_qs8x8(acc21, (char8)a2.s0, b0.s89ABCDEF, FIXED_POINT_POSITION);
        acc21 = mlal_sat_qs8x8(acc21, (char8)a2.s1, b1.s89ABCDEF, FIXED_POINT_POSITION);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        acc30 = mlal_sat_qs8x8(acc30, (char8)a3.s0, b0.s01234567, FIXED_POINT_POSITION);
        acc30 = mlal_sat_qs8x8(acc30, (char8)a3.s1, b1.s01234567, FIXED_POINT_POSITION);
        acc31 = mlal_sat_qs8x8(acc31, (char8)a3.s0, b0.s89ABCDEF, FIXED_POINT_POSITION);
        acc31 = mlal_sat_qs8x8(acc31, (char8)a3.s1, b1.s89ABCDEF, FIXED_POINT_POSITION);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
    }

    // Left-over accumulations
    for(; src_addr.s0 < end_row_vec_a; src_addr += (int2)(1, src1_stride_y))
    {
        char a0 = *((__global char *)(src0_ptr + src_addr.s0 + 0 * src0_stride_y));
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
        char a1 = *((__global char *)(src0_ptr + src_addr.s0 + 1 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
        char a2 = *((__global char *)(src0_ptr + src_addr.s0 + 2 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        char a3 = *((__global char *)(src0_ptr + src_addr.s0 + 3 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        char16 b0 = vload16(0, (__global char *)(src1_ptr + src_addr.s1));

        acc00 = mlal_sat_qs8x8(acc00, (char8)a0, b0.s01234567, FIXED_POINT_POSITION);
        acc01 = mlal_sat_qs8x8(acc01, (char8)a0, b0.s89ABCDEF, FIXED_POINT_POSITION);
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
        acc10 = mlal_sat_qs8x8(acc10, (char8)a1, b0.s01234567, FIXED_POINT_POSITION);
        acc11 = mlal_sat_qs8x8(acc11, (char8)a1, b0.s89ABCDEF, FIXED_POINT_POSITION);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
        acc20 = mlal_sat_qs8x8(acc20, (char8)a2, b0.s01234567, FIXED_POINT_POSITION);
        acc21 = mlal_sat_qs8x8(acc21, (char8)a2, b0.s89ABCDEF, FIXED_POINT_POSITION);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        acc30 = mlal_sat_qs8x8(acc30, (char8)a3, b0.s01234567, FIXED_POINT_POSITION);
        acc31 = mlal_sat_qs8x8(acc31, (char8)a3, b0.s89ABCDEF, FIXED_POINT_POSITION);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
    }

    // Compute destination address
    Image dst = CONVERT_TO_IMAGE_STRUCT(dst);

    // Compute dst address
    __global uchar *dst_addr = offset(&dst, 0, 0);

    // Add offset for batched GEMM
    dst_addr += get_global_id(2) * dst_stride_z;

    // Multiply by the weight of matrix product and store the result
    char16 acc_qs8;
    acc_qs8 = convert_char16_sat((short16)(acc00, acc01));
#if defined(ALPHA)
    acc_qs8 = mul_sat_qs8x16(acc_qs8, (char16)ALPHA, FIXED_POINT_POSITION);
#endif // defined(ALPHA)
    vstore16(acc_qs8, 0, (__global char *)(dst_addr + 0 * dst_stride_y));
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
    acc_qs8 = convert_char16_sat((short16)(acc10, acc11));
#if defined(ALPHA)
    acc_qs8 = mul_sat_qs8x16(acc_qs8, (char16)ALPHA, FIXED_POINT_POSITION);
#endif // defined(ALPHA)
    vstore16(acc_qs8, 0, (__global char *)(dst_addr + 1 * dst_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
    acc_qs8 = convert_char16_sat((short16)(acc20, acc21));
#if defined(ALPHA)
    acc_qs8 = mul_sat_qs8x16(acc_qs8, (char16)ALPHA, FIXED_POINT_POSITION);
#endif // defined(ALPHA)
    vstore16(acc_qs8, 0, (__global char *)(dst_addr + 2 * dst_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
    acc_qs8 = convert_char16_sat((short16)(acc30, acc31));
#if defined(ALPHA)
    acc_qs8 = mul_sat_qs8x16(acc_qs8, (char16)ALPHA, FIXED_POINT_POSITION);
#endif // defined(ALPHA)
    vstore16(acc_qs8, 0, (__global char *)(dst_addr + 3 * dst_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
}

/** This OpenCL kernel computes the matrix by matrix multiplication between the matrix A (src0) and matrix B (src1) in case both matrices have not beed reshaped
 *
 * @note This OpenCL kernel works with fixed point data types QS16
 * @note The number of elements processed along the x and y directions must be passed at compile time using -DNUM_ELEMS_PROCESSED_PER_THREAD_X and -DNUM_ELEMS_PROCESSED_PER_THREAD_Y
 * @note The number of matrix A columns, the number of elements processed per thread along the Y direction and the alpha's value need to be passed at compile time using -DCOLS_A, -DNUM_ELEMS_PROCESSED_PER_THREAD_Y and -DALPHA
 * @note The fixed point position need to be passed at compile time using -DFIXED_POINT_POSITION
 * @note The optional alpha value must be passed in 16 bit fixed point format using -DALPHA
 * @note In case the matrix B has 3 dimensions and the matrix A more than 3, in order to avoid out-of-bounds reads, the number of channels of matrix B must be passed at compile time using MATRIX_B_DEPTH (i.e. -DMATRIX_B_DEPTH=16)
 *       This case can happen when GEMM is used to perform the element-wise multiplication through a batched matrix multiplication (2D Winograd) and we have multiple inputs (i.e. a = [K, M, 16, Batches], b = [N, K, 16])
 *
 * @param[in]  src0_ptr                           Pointer to the source matrix. Supported data types: QS8/QS16
 * @param[in]  src0_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src0_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src0_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src0_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src0_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[in]  src1_ptr                           Pointer to the source matrix. Supported data types: same as @p src0_ptr
 * @param[in]  src1_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src1_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src1_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src1_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src1_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[out] dst_ptr                            Pointer to the destination matrix Supported data types: same as @p src0_ptr
 * @param[in]  dst_stride_x                       Stride of the destination matrix in X dimension (in bytes)
 * @param[in]  dst_step_x                         dst_gx_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  dst_stride_y                       Stride of the destination matrix in Y dimension (in bytes)
 * @param[in]  dst_step_y                         dst_gx_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  dst_offset_first_element_in_bytes  The offset of the first element in the destination matrix
 */
__kernel void gemm_mm_qs16(IMAGE_DECLARATION(src0),
                           IMAGE_DECLARATION(src1),
                           IMAGE_DECLARATION(dst),
                           uint src0_stride_z,
                           uint src1_stride_z,
                           uint dst_stride_z)
{
    int idx = get_global_id(0) * NUM_ELEMS_PROCESSED_PER_THREAD_X;

    // Compute starting address for matrix A and Matrix B
    int2 src_addr = ((int2)(src0_offset_first_element_in_bytes, src1_offset_first_element_in_bytes));

    // Update address for the matrix A
    src_addr.s0 += get_global_id(1) * src0_stride_y * NUM_ELEMS_PROCESSED_PER_THREAD_Y;

    // Update address for the matrix B
    src_addr.s1 += idx * sizeof(short);

    // Add offset for batched GEMM
    src_addr.s0 += get_global_id(2) * src0_stride_z;

#if defined(MATRIX_B_DEPTH)
    // Do not slide matrix B if the matrix B has 3 dimensions and matrix A more than 3
    src_addr.s1 += (get_global_id(2) % MATRIX_B_DEPTH) * src1_stride_z;
#else  // defined(MATRIX_B_DEPTH)
    src_addr.s1 += get_global_id(2) * src1_stride_z;
#endif // defined(MATRIX_B_DEPTH)

    int end_row_vec_a = src_addr.s0 + (COLS_A * sizeof(short));

    int8 acc0 = 0;
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
    int8 acc1 = 0;
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
    int8 acc2 = 0;
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
    int8 acc3 = 0;
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3

    // This for loop performs 4 accumulations per iteration
    for(; src_addr.s0 <= (end_row_vec_a - 2 * (int)sizeof(short)); src_addr += (int2)(2 * sizeof(short), 2 * src1_stride_y))
    {
        short2 a0 = vload2(0, (__global short *)(src0_ptr + src_addr.s0 + 0 * src0_stride_y));
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
        short2 a1 = vload2(0, (__global short *)(src0_ptr + src_addr.s0 + 1 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
        short2 a2 = vload2(0, (__global short *)(src0_ptr + src_addr.s0 + 2 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        short2 a3 = vload2(0, (__global short *)(src0_ptr + src_addr.s0 + 3 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        short8 b0 = vload8(0, (__global short *)(src1_ptr + src_addr.s1 + 0 * src1_stride_y));
        short8 b1 = vload8(0, (__global short *)(src1_ptr + src_addr.s1 + 1 * src1_stride_y));

        acc0 = mlal_sat_qs16x8(acc0, (short8)a0.s0, b0, FIXED_POINT_POSITION);
        acc0 = mlal_sat_qs16x8(acc0, (short8)a0.s1, b1, FIXED_POINT_POSITION);
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
        acc1 = mlal_sat_qs16x8(acc1, (short8)a1.s0, b0, FIXED_POINT_POSITION);
        acc1 = mlal_sat_qs16x8(acc1, (short8)a1.s1, b1, FIXED_POINT_POSITION);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
        acc2 = mlal_sat_qs16x8(acc2, (short8)a2.s0, b0, FIXED_POINT_POSITION);
        acc2 = mlal_sat_qs16x8(acc2, (short8)a2.s1, b1, FIXED_POINT_POSITION);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        acc3 = mlal_sat_qs16x8(acc3, (short8)a3.s0, b0, FIXED_POINT_POSITION);
        acc3 = mlal_sat_qs16x8(acc3, (short8)a3.s1, b1, FIXED_POINT_POSITION);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
    }

    // Left-over accumulations
    for(; src_addr.s0 < end_row_vec_a; src_addr += (int2)(sizeof(short), src1_stride_y))
    {
        short a0 = *((__global short *)(src0_ptr + src_addr.s0 + 0 * src0_stride_y));
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
        short a1 = *((__global short *)(src0_ptr + src_addr.s0 + 1 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
        short a2 = *((__global short *)(src0_ptr + src_addr.s0 + 2 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        short a3 = *((__global short *)(src0_ptr + src_addr.s0 + 3 * src0_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        short8 b0 = vload8(0, (__global short *)(src1_ptr + src_addr.s1));

        acc0 = mlal_sat_qs16x8(acc0, (short8)a0, b0, FIXED_POINT_POSITION);
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
        acc1 = mlal_sat_qs16x8(acc1, (short8)a1, b0, FIXED_POINT_POSITION);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
        acc2 = mlal_sat_qs16x8(acc2, (short8)a2, b0, FIXED_POINT_POSITION);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
        acc3 = mlal_sat_qs16x8(acc3, (short8)a3, b0, FIXED_POINT_POSITION);
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
    }

    // Compute destination address
    Image dst = CONVERT_TO_IMAGE_STRUCT(dst);

    // Compute dst address
    __global uchar *dst_addr = offset(&dst, 0, 0);

    // Add offset for batched GEMM
    dst_addr += get_global_id(2) * dst_stride_z;

    // Multiply by the weight of matrix product and store the result
    short8 acc_qs16;
    acc_qs16 = convert_short8_sat(acc0);
#if defined(ALPHA)
    acc_qs16 = mul_sat_qs16x8(acc_qs16, (short8)ALPHA, FIXED_POINT_POSITION);
#endif // defined(ALPHA)
    vstore8(acc_qs16, 0, (__global short *)(dst_addr + 0 * dst_stride_y));
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
    acc_qs16 = convert_short8_sat(acc1);
#if defined(ALPHA)
    acc_qs16 = mul_sat_qs16x8(acc_qs16, (short8)ALPHA, FIXED_POINT_POSITION);
#endif // defined(ALPHA)
    vstore8(acc_qs16, 0, (__global short *)(dst_addr + 1 * dst_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 1
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
    acc_qs16 = convert_short8_sat(acc2);
#if defined(ALPHA)
    acc_qs16 = mul_sat_qs16x8(acc_qs16, (short8)ALPHA, FIXED_POINT_POSITION);
#endif // defined(ALPHA)
    vstore8(acc_qs16, 0, (__global short *)(dst_addr + 2 * dst_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 2
#if NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
    acc_qs16 = convert_short8_sat(acc3);
#if defined(ALPHA)
    acc_qs16 = mul_sat_qs16x8(acc_qs16, (short8)ALPHA, FIXED_POINT_POSITION);
#endif // defined(ALPHA)
    vstore8(acc_qs16, 0, (__global short *)(dst_addr + 3 * dst_stride_y));
#endif // NUM_ELEMS_PROCESSED_PER_THREAD_Y > 3
}
#endif // defined(FIXED_POINT_POSITION)
#endif // defined(COLS_A) && defined(NUM_ELEMS_PROCESSED_PER_THREAD_X) && (NUM_ELEMS_PROCESSED_PER_THREAD_Y)

#if defined(BETA)
/** This OpenCL kernel performs the in-place matrix addition between 2 matrices taking into account that the second matrix might be weighted by a scalar value beta:
 *
 * @note The beta's value need to be passed at compile time using -DBETA
 *
 * @param[in]  src_ptr                           Pointer to the source matrix. Supported data types: F32
 * @param[in]  src_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[out] dst_ptr                           Pointer to the destination matrix Supported data types: same as @p src_ptr
 * @param[in]  dst_stride_x                      Stride of the destination matrix in X dimension (in bytes)
 * @param[in]  dst_step_x                        dst_gx_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  dst_stride_y                      Stride of the destination matrix in Y dimension (in bytes)
 * @param[in]  dst_step_y                        dst_gx_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  dst_offset_first_element_in_bytes The offset of the first element in the destination matrix
 */
__kernel void gemm_ma_f32(IMAGE_DECLARATION(src),
                          IMAGE_DECLARATION(dst))
{
    // Compute source and destination addresses
    Image src = CONVERT_TO_IMAGE_STRUCT(src);
    Image dst = CONVERT_TO_IMAGE_STRUCT(dst);

    // Load values from A x B
    float4 alpha_ab = vload4(0, (__global float *)dst.ptr);

    // Load values from Matrix C
    float4 c = vload4(0, (__global float *)src.ptr);

    // Computes alpha * axb + beta * c
    float4 out = alpha_ab + (float4)BETA * c;

    // Store final result in axb matrix
    vstore4(out, 0, (__global float *)dst.ptr);
}

/** This OpenCL kernel performs the in-place matrix addition between 2 matrices taking into account that the second matrix might be weighted by a scalar value beta:
 *
 * @note The beta's value need to be passed at compile time using -DBETA
 *
 * @param[in]  src_ptr                           Pointer to the source matrix. Supported data types: F16
 * @param[in]  src_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[out] dst_ptr                           Pointer to the destination matrix Supported data types: same as @p src_ptr
 * @param[in]  dst_stride_x                      Stride of the destination matrix in X dimension (in bytes)
 * @param[in]  dst_step_x                        dst_gx_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  dst_stride_y                      Stride of the destination matrix in Y dimension (in bytes)
 * @param[in]  dst_step_y                        dst_gx_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  dst_offset_first_element_in_bytes The offset of the first element in the destination matrix
 */
__kernel void gemm_ma_f16(IMAGE_DECLARATION(src),
                          IMAGE_DECLARATION(dst))
{
    // Compute source and destination addresses
    Image src = CONVERT_TO_IMAGE_STRUCT(src);
    Image dst = CONVERT_TO_IMAGE_STRUCT(dst);

    // Load values from A x B
    half8 alpha_ab = vload8(0, (__global half *)dst.ptr);

    // Load values from Matrix C
    half8 c = vload8(0, (__global half *)src.ptr);

    // Computes alpha * axb + beta * c
    half8 out = alpha_ab + (half8)BETA * c;

    // Store final result in axb matrix
    vstore8(out, 0, (__global half *)dst.ptr);
}

#if defined(FIXED_POINT_POSITION)
/** This OpenCL kernel performs the in-place matrix addition between 2 matrices in 8 bit fixed point taking into account that the second matrix might be weighted by a scalar value beta:
 *
 * @note The beta's value and the fixed point position need to be passed at compile time using -DBETA and -DFIXED_POINT_POSITION
 *
 * @note: BETA must be passed in 8 bit fixed point format
 *
 * @param[in]  src_ptr                           Pointer to the source matrix. Supported data types: QS8
 * @param[in]  src_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[out] dst_ptr                           Pointer to the destination matrix Supported data types: same as @p src_ptr
 * @param[in]  dst_stride_x                      Stride of the destination matrix in X dimension (in bytes)
 * @param[in]  dst_step_x                        dst_gx_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  dst_stride_y                      Stride of the destination matrix in Y dimension (in bytes)
 * @param[in]  dst_step_y                        dst_gx_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  dst_offset_first_element_in_bytes The offset of the first element in the destination matrix
 */
__kernel void gemm_ma_qs8(IMAGE_DECLARATION(src),
                          IMAGE_DECLARATION(dst))
{
    // Compute source and destination addresses
    Image src = CONVERT_TO_IMAGE_STRUCT(src);
    Image dst = CONVERT_TO_IMAGE_STRUCT(dst);

    // Load values from A x B
    char16 alpha_ab = vload16(0, (__global char *)dst.ptr);

    // Load values from Matrix C
    char16 c = vload16(0, (__global char *)src.ptr);

    // Computes alpha * axb + beta * c
    char16 out = mla_sat_qs8x16(alpha_ab, (char16)BETA, c, FIXED_POINT_POSITION);

    // Store final result in axb matrix
    vstore16(out, 0, (__global char *)dst.ptr);
}

/** This OpenCL kernel performs the in-place matrix addition between 2 matrices in 16 bit fixed point taking into account that the second matrix might be weighted by a scalar value beta:
 *
 * @note The beta's value and the fixed point position need to be passed at compile time using -DBETA and -DFIXED_POINT_POSITION
 *
 * @note: BETA must be passed in 16 bit fixed point format
 *
 * @param[in]  src_ptr                           Pointer to the source matrix. Supported data types: QS16
 * @param[in]  src_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[out] dst_ptr                           Pointer to the destination matrix Supported data types: same as @p src_ptr
 * @param[in]  dst_stride_x                      Stride of the destination matrix in X dimension (in bytes)
 * @param[in]  dst_step_x                        dst_gx_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  dst_stride_y                      Stride of the destination matrix in Y dimension (in bytes)
 * @param[in]  dst_step_y                        dst_gx_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  dst_offset_first_element_in_bytes The offset of the first element in the destination matrix
 */
__kernel void gemm_ma_qs16(IMAGE_DECLARATION(src),
                           IMAGE_DECLARATION(dst))
{
    // Compute source and destination addresses
    Image src = CONVERT_TO_IMAGE_STRUCT(src);
    Image dst = CONVERT_TO_IMAGE_STRUCT(dst);

    // Load values from A x B
    short8 alpha_ab = vload8(0, (__global short *)dst.ptr);

    // Load values from Matrix C
    short8 c = vload8(0, (__global short *)src.ptr);

    // Computes alpha * axb + beta * c
    short8 out = mla_sat_qs16x8(alpha_ab, (short8)BETA, c, FIXED_POINT_POSITION);

    // Store final result in axb matrix
    vstore8(out, 0, (__global short *)dst.ptr);
}
#endif // defined(FIXED_POINT_POSITION)
#endif // defined(BETA)

#if defined(WIDTH_VECTOR_A)
/** This OpenCL kernel computes the vector by matrix multiplication between each row of A (src0) and matrix B (src1) used for locally connected layer
 *
 * @note The width of A need to be passed at compile time using -DWIDTH_VECTOR_A
 *
 * @note The input A and matrix B must not be reshaped
 *
 * @param[in]  src0_ptr                           Pointer to the source matrix. Supported data types: F32
 * @param[in]  src0_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src0_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src0_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src0_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src0_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[in]  src1_ptr                           Pointer to the source matrix. Supported data types: same as @p src0_ptr
 * @param[in]  src1_stride_x                      Stride of the source matrix in X dimension (in bytes)
 * @param[in]  src1_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src1_stride_y                      Stride of the source matrix in Y dimension (in bytes)
 * @param[in]  src1_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src1_stride_z                      Stride of the source matrix in Z dimension (in bytes)
 * @param[in]  src1_step_z                        src_stride_z * number of elements along Z processed per workitem(in bytes)
 * @param[in]  src1_offset_first_element_in_bytes The offset of the first element in the source matrix
 * @param[out] dst_ptr                            Pointer to the destination matrix Supported data types: same as @p src0_ptr
 * @param[in]  dst_stride_x                       Stride of the destination matrix in X dimension (in bytes)
 * @param[in]  dst_step_x                         dst_gx_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  dst_stride_y                       Stride of the destination matrix in Y dimension (in bytes)
 * @param[in]  dst_step_y                         dst_gx_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  dst_offset_first_element_in_bytes  The offset of the first element in the destination matrix
 */
__kernel void gemm_lc_vm_f32(IMAGE_DECLARATION(src0),
                             TENSOR3D_DECLARATION(src1),
                             IMAGE_DECLARATION(dst))
{
    int idx = get_global_id(0) * 4;
    int idy = get_global_id(1);

    // Compute the address for the vector A and matrix B
    int2 src_addr = ((int2)(src0_offset_first_element_in_bytes + src0_stride_y * idy, src1_offset_first_element_in_bytes + src1_stride_z * idy));
    src_addr.s1 += idx * sizeof(float);

    int end_row_vec_a = src_addr.s0 + (WIDTH_VECTOR_A * sizeof(float));

    float4 acc = 0.0f;

    for(; src_addr.s0 <= (end_row_vec_a - 2 * (int)sizeof(float)); src_addr += (int2)(2 * sizeof(float), 2 * src1_stride_y))
    {
        float2 a0 = vload2(0, (__global float *)(src0_ptr + src_addr.s0));
        float4 b0 = vload4(0, (__global float *)(src1_ptr + src_addr.s1));
        float4 b1 = vload4(0, (__global float *)(src1_ptr + src_addr.s1 + src1_stride_y));

        acc += b0 * (float4)a0.s0;
        acc += b1 * (float4)a0.s1;
    }

    for(; src_addr.s0 < end_row_vec_a; src_addr += (int2)(sizeof(float), src1_stride_y))
    {
        float  a0 = *((__global float *)(src0_ptr + src_addr.s0));
        float4 b0 = vload4(0, (__global float *)(src1_ptr + src_addr.s1));

        acc += b0 * (float4)a0;
    }

    // Compute destination address
    Image dst = CONVERT_TO_IMAGE_STRUCT(dst);

    vstore4(acc, 0, (__global float *)(offset(&dst, 0, 0)));
}
#endif // defined(WIDTH_VECTOR_A)

/** This kernel accumulates each row with the biases vector.
 *
 * @note The data type must be passed at compile time using -DDATA_TYPE e.g. -DDATA_TYPE=short.
 * @note The vector size must be passed at compile time using -DVECTOR_SIZE e.g. -DVECTOR_SIZE=16.
 *
 * @param[in, out] accum_ptr                            Pointer to the accumulate tensor. Supported data type: U8/S8/QS8/U16/S16/F16/U32/S32/F32
 * @param[in]      accum_stride_x                       Stride of the accmulate tensor in X dimension (in bytes)
 * @param[in]      accum_step_x                         accum_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]      accum_stride_y                       Stride of the accumlulate tensor in Y dimension (in bytes)
 * @param[in]      accum_step_y                         src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]      accum_offset_first_element_in_bytes  The offset of the first element in the accumulate tensor
 * @param[in]      biases_ptr                           Pointer to the biases vector. Same as @p accum_ptr
 * @param[in]      biases_stride_x                      Stride of the destination tensor in X dimension (in bytes)
 * @param[in]      biases_step_x                        dst_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]      biases_offset_first_element_in_bytes The offset of the first element in the destination tensor
 */
#if defined(DATA_TYPE) && defined(VECTOR_SIZE)
__kernel void gemm_accumulate_biases(
    IMAGE_DECLARATION(accum),
    VECTOR_DECLARATION(biases))
{
    Image  accum  = CONVERT_TO_IMAGE_STRUCT(accum);
    Vector biases = CONVERT_TO_VECTOR_STRUCT(biases);

    // Vector size, i.e. number of vector elements.
    VEC_DATA_TYPE(DATA_TYPE, VECTOR_SIZE)
    accum_value = VLOAD(VECTOR_SIZE)(0, (__global DATA_TYPE *)accum.ptr);
    VEC_DATA_TYPE(DATA_TYPE, VECTOR_SIZE)
    biases_value = VLOAD(VECTOR_SIZE)(0, (__global DATA_TYPE *)biases.ptr);
#ifdef FIXED_POINT_POSITION
    accum_value = ADD_SAT_OP_EXPAND(biases_value, accum_value, DATA_TYPE, VECTOR_SIZE);
#else  // FIXED_POINT_POSITION
    accum_value = biases_value + accum_value;
#endif // FIXED_POINT_POSITION
    // Store result in the accumulate buffer
    VSTORE(VECTOR_SIZE)
    (accum_value, 0, (__global DATA_TYPE *)accum.ptr);
}
#endif // defined(DATA_TYPE) && defined(VECTOR_SIZE)
