import 'package:flutter/material.dart';
import '../models/review_model.dart';
import '../repositories/review_repository.dart';
import '../services/review_service.dart';

class ReviewProvider extends ChangeNotifier {
  final ReviewRepository _reviewRepository;
  final ReviewService _reviewService;

  List<ReviewModel> _stationReviews = [];
  bool _isLoading = false;

  ReviewProvider({
    required ReviewRepository reviewRepository,
    required ReviewService reviewService,
  })  : _reviewRepository = reviewRepository,
        _reviewService = reviewService;

  List<ReviewModel> get stationReviews => _stationReviews;
  bool get isLoading => _isLoading;

  Future<void> fetchStationReviews(String stationId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _stationReviews = await _reviewRepository.getStationReviews(stationId);
    } catch (e) {
      debugPrint("Error fetching reviews: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> submitReview(ReviewModel review) async {
    if (!_reviewService.validateReview(review.comment, review.rating)) {
      return false;
    }

    try {
      await _reviewRepository.submitReview(review);
      // Optimistic update
      _stationReviews.insert(0, review);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Error submitting review: $e");
      return false;
    }
  }
}
