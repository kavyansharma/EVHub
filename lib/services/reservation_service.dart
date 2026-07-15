class ReservationService {
  
  double calculateReservationCost(DateTime start, DateTime end, double ratePerMin) {
    final duration = end.difference(start).inMinutes;
    if (duration <= 0) return 0.0;
    
    // Base fee + duration * rate
    const double baseFee = 20.0; // INR
    return baseFee + (duration * ratePerMin);
  }

  bool validateReservationTime(DateTime start, DateTime end) {
    final now = DateTime.now();
    // Cannot reserve in the past
    if (start.isBefore(now)) return false;
    // Must reserve for at least 15 mins
    if (end.difference(start).inMinutes < 15) return false;
    // Cannot reserve more than 24 hours in advance
    if (start.difference(now).inHours > 24) return false;
    
    return true;
  }
}
