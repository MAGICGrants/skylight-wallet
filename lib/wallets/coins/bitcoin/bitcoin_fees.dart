/// Derives a fee rate (sat/vB) from an Electrum `mempool.get_fee_histogram`
/// response.
///
/// [histogram] is `[[feerateSatVb, vsize], ...]` sorted by fee rate
/// descending. Walking from the top, the fee rates fill blocks (~1,000,000
/// vbytes each); the rate at which cumulative vsize first covers
/// `targetBlocks` worth of space is what you must pay to confirm within that
/// many blocks. Returns [floorSatVb] when the mempool is smaller than that
/// (uncongested) or the histogram is empty.
const int _blockVsize = 1000000;

double feeRateForBlocks(
  List<List<num>> histogram,
  int targetBlocks, {
  double floorSatVb = 1,
}) {
  if (histogram.isEmpty || targetBlocks < 1) return floorSatVb;
  final capacity = _blockVsize * targetBlocks;
  var cumulative = 0.0;
  for (final bucket in histogram) {
    if (bucket.length < 2) continue;
    final feerate = bucket[0].toDouble();
    cumulative += bucket[1].toDouble();
    if (cumulative >= capacity) {
      return feerate < floorSatVb ? floorSatVb : feerate;
    }
  }
  // Mempool doesn't fill the target → uncongested; the floor is enough.
  return floorSatVb;
}
