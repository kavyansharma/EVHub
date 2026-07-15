class ReviewService {
  
  bool validateReview(String comment, double rating) {
    if (rating < 1.0 || rating > 5.0) return false;
    if (comment.trim().isEmpty) return false;
    // Simple profanity check (placeholder for ML check or better regex)
    final profanity = ['badword1', 'badword2']; 
    final lowerComment = comment.toLowerCase();
    for (var word in profanity) {
      if (lowerComment.contains(word)) return false;
    }
    return true;
  }
}
