part of three_webgpu;

int getFloatLength(int floatLength) {
  // ensure chunk size alignment (STD140 layout)

  return floatLength +
      ((GPUChunkSize - (floatLength % GPUChunkSize)) % GPUChunkSize);
}

int getVectorLength(int count, [int vectorLength = 4]) {
  final strideLength = getStrideLength(vectorLength);

  final floatLength = strideLength * count;

  return getFloatLength(floatLength);
}

int getStrideLength(int vectorLength) {
  final strideLength = 4;

  return vectorLength +
      ((strideLength - (vectorLength % strideLength)) % strideLength);
}
