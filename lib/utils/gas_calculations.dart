const double kEmptyCylinderWeightKg = 19.1;
const double kFullCylinderWeightKg = 38.0;
const double kMaxGasContentPerCylinderKg = kFullCylinderWeightKg - kEmptyCylinderWeightKg;

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
