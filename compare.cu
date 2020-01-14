#include <cstdio>
#include <cuda_runtime.h>

#define RADIUS                3
#define THREADS_PER_BLOCK     512

__global__ void windowSumNaiveKernel(const float* A, float* B, int n) {
  int out_index = blockDim.x * blockIdx.x + threadIdx.x;
  int in_index = out_index + RADIUS;
  if (out_index < n) {
    float sum = 0.;
#pragma unroll
    for (int i = -RADIUS; i <= RADIUS; ++i) {
      sum += A[in_index + i];
    }
    B[out_index] = sum;
  }
}

__global__ void windowSumKernel(const float* A, float* B, int n) {
  __shared__ float temp[THREADS_PER_BLOCK + 2 * RADIUS];
  int out_index = blockDim.x * blockIdx.x + threadIdx.x;
  int in_index = out_index + RADIUS;
  int local_index = threadIdx.x + RADIUS;
  if (out_index < n) {
    temp[local_index] = A[in_index];
    if (threadIdx.x < RADIUS) {
      temp[local_index - RADIUS] = A[in_index - RADIUS];
      temp[local_index + THREADS_PER_BLOCK] = A[in_index +  THREADS_PER_BLOCK];
    }
    __syncthreads();
    float sum = 0.;
#pragma unroll
    for (int i = -RADIUS; i <= RADIUS; ++i) {
      sum += temp[local_index + i];
    }
    B[out_index] = sum;
  }
}

void windowSumNaive(const float* A, float* B, int n) {
    float *d_A, *d_B;
    int size = n * sizeof(float);
    cudaMalloc((void **) &d_A, (n + 2 * RADIUS) * sizeof(float));
    cudaMemset(d_A, 0, (n + 2 * RADIUS) * sizeof(float));
    cudaMemcpy(d_A + RADIUS, A, size, cudaMemcpyHostToDevice);
    cudaMalloc((void **) &d_B, size);
    dim3 threads(THREADS_PER_BLOCK, 1, 1);
    dim3 blocks((n + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK, 1, 1);
    windowSumNaiveKernel<<<blocks, threads>>>(d_A, d_B, n);
    cudaMemcpy(B, d_B, size, cudaMemcpyDeviceToHost);
    cudaFree(d_A);
    cudaFree(d_B);
}

void windowSum(const float* A, float* B, int n) {
    float *d_A, *d_B;
    int size = n * sizeof(float);
    cudaMalloc((void **) &d_A, (n + 2 * RADIUS) * sizeof(float));
    cudaMemset(d_A, 0, (n + 2 * RADIUS) * sizeof(float));
    cudaMemcpy(d_A + RADIUS, A, size, cudaMemcpyHostToDevice);
    cudaMalloc((void **) &d_B, size);
    dim3 threads(THREADS_PER_BLOCK, 1, 1);
    dim3 blocks((n + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK, 1, 1);
    windowSumKernel<<<blocks, threads>>>(d_A, d_B, n);
    cudaMemcpy(B, d_B, size, cudaMemcpyDeviceToHost);
    cudaFree(d_A);
    cudaFree(d_B);
}

int main() {
  int n = 1024 * 1024;
  float* A = new float[n];
  float* B = new float[n];
  for (int i = 0; i < n; ++i) {
    A[i] = i;
  }
  
  cudaEvent_t start, stop;
  float elapsedTime = 0.0;
  cudaEventCreate(&start);
  cudaEventCreate(&stop);
  cudaEventRecord(start, 0);

  windowSumNaive(A, B, n);
  
  cudaEventRecord(stop, 0);
  cudaEventSynchronize(stop);
  cudaEventElapsedTime(&elapsedTime, start, stop);
  printf("windowSumNaive: %f ms\n", elapsedTime);
  // cudaEventDestroy(start);
  // cudaEventDestroy(stop);
  
  // cudaEvent_t start, stop;
  elapsedTime = 0.0;
  cudaEventCreate(&start);
  cudaEventCreate(&stop);
  cudaEventRecord(start, 0);

  windowSum(A, B, n);

  cudaEventRecord(stop, 0);
  cudaEventSynchronize(stop);
  cudaEventElapsedTime(&elapsedTime, start, stop);
  printf("windowSum: %f ms\n", elapsedTime);

  cudaEventDestroy(start);
  cudaEventDestroy(stop);

  delete [] A;
  delete [] B;
  return 0;
}
