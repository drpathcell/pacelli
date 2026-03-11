import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/data_repository_provider.dart';
import '../../../core/models/search_result.dart';

/// Parameters for a household search query.
class SearchParams extends Equatable {
  final String householdId;
  final String query;
  final Set<String> entityTypes;

  const SearchParams({
    required this.householdId,
    required this.query,
    this.entityTypes = const {'task', 'checklist', 'plan', 'attachment', 'inventory'},
  });

  @override
  List<Object?> get props => [householdId, query, entityTypes];
}

/// Active entity-type filter chips. Defaults to all types enabled.
final searchFilterProvider = StateProvider<Set<String>>(
  (_) => const {'task', 'checklist', 'plan', 'attachment', 'inventory'},
);

/// Debounced search provider. Returns results for the given [SearchParams].
final searchProvider =
    FutureProvider.autoDispose.family<List<SearchResult>, SearchParams>(
  (ref, params) async {
    // Skip empty or very short queries.
    if (params.query.trim().length < 2) return const [];

    // 300ms debounce — cancel if params change within the window.
    final completer = Completer<void>();
    final timer = Timer(const Duration(milliseconds: 300), completer.complete);
    ref.onDispose(timer.cancel);
    await completer.future;

    final repo = ref.watch(dataRepositoryProvider);
    return repo.searchHousehold(
      householdId: params.householdId,
      query: params.query.trim(),
      entityTypes: params.entityTypes.toList(),
    );
  },
);
