import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/connectivity/OfflineCubit.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../core/result/failure.dart';
import '../../../../design/design.dart';
import '../widgets/explore_actions.dart';
import 'library_facets_cubit.dart';

/// Library exploration (v0.4.4, ADR-0034): genre and decade entry points
/// built from the user's own library, plus a random album/artist pick —
/// intentional browsing without an opaque recommendation service.
///
/// A plain scrolling column rather than another [PagedCollectionView]:
/// nothing here is a collection to page through, it is a small, fixed set
/// of ways into one, so a `ListView` of independent sections is the right
/// shape (the same reasoning Home's sections use).
class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    context.read<LibraryFacetsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = context.tokens;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        t.spacing.md,
        t.spacing.md,
        t.spacing.md,
        t.spacing.xxl,
      ),
      children: [
        const _RandomPickSection(),
        SizedBox(height: t.spacing.lg),
        BlocBuilder<LibraryFacetsCubit, LibraryFacetsState>(
          builder: (context, state) => _GenreShelf(state: state),
        ),
        SizedBox(height: t.spacing.lg),
        BlocBuilder<LibraryFacetsCubit, LibraryFacetsState>(
          builder: (context, state) => _DecadeShelf(state: state),
        ),
      ],
    );
  }
}

/// "Surprise me" — a deliberate random album or artist from the active
/// library scope: the whole server library online, the profile's
/// downloads while offline (`MusicLibraryRepository.randomAlbum`'s doc
/// comment). The caption always says which, so a pick is never a mystery
/// about what it drew from.
class _RandomPickSection extends StatefulWidget {
  const _RandomPickSection();

  @override
  State<_RandomPickSection> createState() => _RandomPickSectionState();
}

class _RandomPickSectionState extends State<_RandomPickSection> {
  bool _pickingAlbum = false;
  bool _pickingArtist = false;

  Future<void> _pickAlbum() async {
    setState(() => _pickingAlbum = true);
    await pickRandomAlbum(context);
    if (mounted) setState(() => _pickingAlbum = false);
  }

  Future<void> _pickArtist() async {
    setState(() => _pickingArtist = true);
    await pickRandomArtist(context);
    if (mounted) setState(() => _pickingArtist = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final offline = context.watch<OfflineCubit>().state.isOffline;
    final busy = _pickingAlbum || _pickingArtist;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Surprise me',
          style: t.typography.titleMedium.copyWith(
            color: t.colors.textPrimary,
          ),
        ),
        SizedBox(height: t.spacing.xxs),
        Text(
          offline
              ? 'A random pick from what you have downloaded.'
              : 'A random pick from your whole library.',
          style: t.typography.bodyMedium.copyWith(
            color: t.colors.textSecondary,
          ),
        ),
        SizedBox(height: t.spacing.sm),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: _pickingAlbum ? 'Picking…' : 'Album',
                icon: Icons.album_outlined,
                variant: AppButtonVariant.secondary,
                expand: true,
                onPressed: busy ? null : _pickAlbum,
              ),
            ),
            SizedBox(width: t.spacing.sm),
            Expanded(
              child: AppButton(
                label: _pickingArtist ? 'Picking…' : 'Artist',
                icon: Icons.person_outline_rounded,
                variant: AppButtonVariant.secondary,
                expand: true,
                onPressed: busy ? null : _pickArtist,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Genre entry points (v0.4.4): every genre name the library reports, each
/// a chip that opens its own filtered album shelf. Live only —
/// `LibraryFacetsCubit`'s doc comment — so this renders loading, a
/// server-only "unavailable" message, or the chips, honestly telling them
/// apart rather than just disappearing.
class _GenreShelf extends StatelessWidget {
  const _GenreShelf({required this.state});

  final LibraryFacetsState state;

  @override
  Widget build(BuildContext context) {
    return _FacetShelf(
      title: 'Genres',
      isLoading: state.genresLoading,
      failure: state.genresFailure,
      isEmpty: state.hasLoadedGenres && state.genres.isEmpty,
      emptyMessage: 'No genres tagged in your library yet.',
      chips: [
        for (final genre in state.genres)
          ActionChip(
            label: Text(genre),
            onPressed: () => context.pushNamed(
              RouteNames.libraryGenre,
              pathParameters: {'name': genre},
            ),
          ),
      ],
    );
  }
}

/// Decade entry points (v0.4.4): every decade the library's albums span,
/// newest first, each a chip that opens its own filtered album shelf.
class _DecadeShelf extends StatelessWidget {
  const _DecadeShelf({required this.state});

  final LibraryFacetsState state;

  @override
  Widget build(BuildContext context) {
    return _FacetShelf(
      title: 'Decades',
      isLoading: state.decadesLoading,
      failure: state.decadesFailure,
      isEmpty: state.hasLoadedDecades && state.decades.isEmpty,
      emptyMessage: 'No album release years in your library yet.',
      chips: [
        for (final decade in state.decades)
          ActionChip(
            label: Text('${decade}s'),
            onPressed: () => context.pushNamed(
              RouteNames.libraryDecade,
              pathParameters: {'decade': '$decade'},
            ),
          ),
      ],
    );
  }
}

/// The shape [_GenreShelf] and [_DecadeShelf] share: a heading, then
/// loading placeholders, an honest "needs a connection" line, an honest
/// "nothing yet" line, or the chips — never a silent gap.
class _FacetShelf extends StatelessWidget {
  const _FacetShelf({
    required this.title,
    required this.isLoading,
    required this.failure,
    required this.isEmpty,
    required this.emptyMessage,
    required this.chips,
  });

  final String title;
  final bool isLoading;
  final Failure? failure;
  final bool isEmpty;
  final String emptyMessage;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: t.typography.titleMedium.copyWith(
            color: t.colors.textPrimary,
          ),
        ),
        SizedBox(height: t.spacing.sm),
        if (isLoading)
          Wrap(
            spacing: t.spacing.sm,
            runSpacing: t.spacing.sm,
            children: [
              for (var i = 0; i < 4; i++)
                AppSkeleton(
                  width: 72 + (i.isEven ? 16 : 0),
                  height: 32,
                  borderRadius: BorderRadius.circular(t.radii.pill),
                ),
            ],
          )
        else if (failure != null)
          _InlineStatusLine(message: 'Needs a connection: ${failure!.message}')
        else if (isEmpty)
          _InlineStatusLine(message: emptyMessage)
        else
          Wrap(
            spacing: t.spacing.sm,
            runSpacing: t.spacing.sm,
            children: chips,
          ),
      ],
    );
  }
}

class _InlineStatusLine extends StatelessWidget {
  const _InlineStatusLine({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        Icon(Icons.cloud_off_rounded, size: 14, color: t.colors.textSecondary),
        SizedBox(width: t.spacing.xs),
        Expanded(
          child: Text(
            message,
            style: t.typography.caption.copyWith(color: t.colors.textSecondary),
          ),
        ),
      ],
    );
  }
}
