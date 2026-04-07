const double kEmptyCylinderWeightKg = 19.1;
const double kFullCylinderWeightKg = 38.0;
const double kMaxGasContentPerCylinderKg = kFullCylinderWeightKg - kEmptyCylinderWeightKg;
const double kHighUsageFallbackThresholdKg = 8.0;

class UsageValidationResult {
  const UsageValidationResult({
    required this.usage,
    required this.warnings,
  });

  final double usage;
  final List<String> warnings;
}

double calculateGrossTotal(List<double> weights) {
  return weights.fold<double>(0, (total, weight) => total + weight);
}

double calculateTareWeight(int connectedCount) {
  return connectedCount * kEmptyCylinderWeightKg;
}

double clampGas(double value) {
  if (value <= 0) return 0;
  if (value.abs() < 0.000001) return 0;
  return value;
}

double calculateGasRemaining(List<double> weights, int connectedCount) {
  final grossTotal = calculateGrossTotal(weights);
  return clampGas(grossTotal - calculateTareWeight(connectedCount));
}

double calculateUsage(double previousGasRemaining, double currentGasRemaining) {
  final usage = previousGasRemaining - currentGasRemaining;
  if (usage < 0.000001) return 0;
  return usage;
}

double calculateDailyUsage(
  double previousGasRemaining,
  double currentGasRemaining, {
  int addedCylinders = 0,
}) {
  final addedGas = addedCylinders * kMaxGasContentPerCylinderKg;
  return calculateUsage(
    previousGasRemaining + addedGas,
    currentGasRemaining,
  );
}

UsageValidationResult calculateDailyUsageWithWarnings(
  double previousGasRemaining,
  double currentGasRemaining, {
  int addedCylinders = 0,
  int removedCylinders = 0,
  double? sevenDayAverageUsage,
}) {
  final warnings = <String>[];
  final addedGas = addedCylinders * kMaxGasContentPerCylinderKg;
  final rawUsage = (previousGasRemaining + addedGas) - currentGasRemaining;
  var usage = calculateDailyUsage(
    previousGasRemaining,
    currentGasRemaining,
    addedCylinders: addedCylinders,
  );

  if (currentGasRemaining > previousGasRemaining && addedCylinders == 0) {
    warnings.add('Gas increased but no cylinders were added. Please verify entries.');
  }

  if (rawUsage < 0 && addedCylinders == 0) {
    usage = 0;
    warnings.add('Invalid gas calculation detected. Check cylinder entries.');
  }

  final highUsageThreshold = sevenDayAverageUsage != null && sevenDayAverageUsage > 0
      ? sevenDayAverageUsage * 2
      : kHighUsageFallbackThresholdKg;

  if (currentGasRemaining < previousGasRemaining &&
      usage > highUsageThreshold &&
      removedCylinders == 0) {
    warnings.add('High gas drop detected. Did you remove empty cylinders?');
  }

  if (removedCylinders > 0 &&
      (currentGasRemaining >= previousGasRemaining || usage < 0.5)) {
    warnings.add('Removed cylinders recorded. Please verify weights and cylinder count.');
  }

  return UsageValidationResult(
    usage: clampGas(usage),
    warnings: warnings,
  );
}
