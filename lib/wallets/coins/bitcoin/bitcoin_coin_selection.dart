/// Branch-and-bound coin selection (Bitcoin Core style).
///
/// Finds a subset of UTXOs whose summed *effective* values land within
/// `[target, target + costOfChange]`, i.e. a changeless spend that overpays by
/// at most the cost of creating + later spending a change output. Returns null
/// when no such subset exists — the caller then falls back to a selection that
/// produces a change output.
///
/// All values are in satoshis. [effectiveValues] are already net of each
/// input's spending fee (`value - feeRate * inputVsize`); [target] is the send
/// amount plus the input-independent fee (overhead + recipient output).
List<int>? branchAndBoundSelect({
  required List<int> effectiveValues,
  required int target,
  required int costOfChange,
  int maxTries = 100000,
}) {
  final n = effectiveValues.length;
  if (n == 0 || target <= 0) return null;

  // Descending by effective value; keep a map back to original indices.
  final order = List<int>.generate(n, (i) => i)
    ..sort((a, b) => effectiveValues[b].compareTo(effectiveValues[a]));
  final vals = [for (final i in order) effectiveValues[i]];

  // Suffix sums for the lower-bound cut: if even all remaining can't reach
  // the target, prune.
  final suffix = List<int>.filled(n + 1, 0);
  for (var i = n - 1; i >= 0; i--) {
    suffix[i] = suffix[i + 1] + vals[i];
  }

  final upper = target + costOfChange;
  var tries = 0;
  final picked = <int>[];
  List<int>? result;

  bool dfs(int idx, int sum) {
    if (tries++ > maxTries) return false;
    if (sum > upper) return false; // overshoot the window
    if (sum + suffix[idx] < target) return false; // can't reach target
    if (sum >= target) {
      result = List<int>.from(picked); // within [target, upper]
      return true;
    }
    if (idx >= n) return false;
    // Inclusion branch first (greedy toward larger values).
    picked.add(idx);
    if (dfs(idx + 1, sum + vals[idx])) return true;
    picked.removeLast();
    return dfs(idx + 1, sum);
  }

  dfs(0, 0);
  if (result == null) return null;
  return [for (final p in result!) order[p]];
}
