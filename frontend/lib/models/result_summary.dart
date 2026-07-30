import 'restaurant_preview.dart';

class RestaurantResult {
  const RestaurantResult({
    required this.voteResult,
    required this.peopleCount,
    required this.rank,
  });

  final RestaurantVoteResult voteResult;
  final int peopleCount;
  final int rank;

  RestaurantPreview get restaurant => voteResult.restaurant;
  int get likeCount => voteResult.likeCount;
  int get rejectCount => voteResult.rejectCount;
  double get likeRate => peopleCount == 0 ? 0 : likeCount / peopleCount;
  bool get isUnanimous => peopleCount > 0 && likeCount == peopleCount;
}

class ResultSummary {
  const ResultSummary({
    required this.rankedResults,
    required this.topResults,
    required this.peopleCount,
  });

  factory ResultSummary.fromMatchResult(RestaurantMatchResult result) {
    final sortedResults = [...result.results]
      ..sort((a, b) {
        final likeComparison = b.likeCount.compareTo(a.likeCount);
        if (likeComparison != 0) {
          return likeComparison;
        }
        return a.rejectCount.compareTo(b.rejectCount);
      });

    final rankedResults = <RestaurantResult>[];
    var previousLikeCount = -1;
    var currentRank = 0;
    for (var index = 0; index < sortedResults.length; index++) {
      final voteResult = sortedResults[index];
      if (voteResult.likeCount != previousLikeCount) {
        currentRank = index + 1;
        previousLikeCount = voteResult.likeCount;
      }
      rankedResults.add(
        RestaurantResult(
          voteResult: voteResult,
          peopleCount: result.peopleCount,
          rank: currentRank,
        ),
      );
    }

    final topLikeCount = rankedResults.isEmpty
        ? 0
        : rankedResults.first.likeCount;
    return ResultSummary(
      rankedResults: rankedResults,
      topResults: rankedResults
          .where((result) => result.likeCount == topLikeCount)
          .toList(),
      peopleCount: result.peopleCount,
    );
  }

  final List<RestaurantResult> rankedResults;
  final List<RestaurantResult> topResults;
  final int peopleCount;

  RestaurantResult get winner => topResults.first;
  bool get hasTie => topResults.length > 1;
  List<RestaurantResult> get podiumResults => rankedResults.take(3).toList();
}
