import 'package:flutter/material.dart';
import 'package:popcorn_flutter/src/details/view/details_translations.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/search/domain/media_person.dart';
import 'package:popcorn_flutter/src/search/domain/media_search_repository.dart';

/// A TMDB-style person profile with biography and a selectable known-for rail.
class PersonDetailsPage extends StatefulWidget {
  const PersonDetailsPage({super.key, required this.personId, required this.repository, required this.onCreditSelected});

  final int personId;
  final MediaSearchRepository repository;
  final ValueChanged<PersonCredit> onCreditSelected;

  @override
  State<PersonDetailsPage> createState() => _PersonDetailsPageState();
}

class _PersonDetailsPageState extends State<PersonDetailsPage> {
  late Future<MediaPerson> _personFuture = widget.repository.personDetails(widget.personId);

  void _retry() => setState(() => _personFuture = widget.repository.personDetails(widget.personId));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MediaPerson>(
      future: _personFuture,
      builder: (context, snapshot) {
        final person = snapshot.data;
        return Scaffold(
          appBar: AppBar(title: Text(person?.name ?? '')),
          body: SafeArea(
            child: switch (snapshot.connectionState) {
              ConnectionState.waiting => const Center(child: CircularProgressIndicator()),
              _ when snapshot.hasError || person == null => _PersonError(onRetry: _retry),
              _ => _PersonProfile(person: person, onCreditSelected: widget.onCreditSelected),
            },
          ),
        );
      },
    );
  }
}

class _PersonProfile extends StatelessWidget {
  const _PersonProfile({required this.person, required this.onCreditSelected});

  final MediaPerson person;
  final ValueChanged<PersonCredit> onCreditSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final posterWidth = constraints.maxWidth < 520 ? 110.0 : 160.0;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PersonPortrait(person: person, width: posterWidth, height: posterWidth * 1.5),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(person.name, style: theme.textTheme.headlineMedium),
                          if (person.knownForDepartment?.isNotEmpty == true) ...[
                            const SizedBox(height: 8),
                            Text(person.knownForDepartment!, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          ],
                          if (person.birthday != null) ...[
                            const SizedBox(height: 16),
                            _PersonFact(
                              label: DetailsTranslations.personBorn.trOf(context),
                              value: _date(person.birthday!) + (person.placeOfBirth == null ? '' : ' · ${person.placeOfBirth}'),
                            ),
                          ],
                          if (person.deathday != null) ...[
                            const SizedBox(height: 8),
                            _PersonFact(label: DetailsTranslations.personDied.trOf(context), value: _date(person.deathday!)),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            if (person.biography.trim().isNotEmpty) ...[
              const SizedBox(height: 32),
              Text(DetailsTranslations.personBiography.trOf(context), style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              Text(person.biography.trim(), style: theme.textTheme.bodyLarge),
            ],
            const SizedBox(height: 32),
            Text(DetailsTranslations.personKnownFor.trOf(context), style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            if (person.knownFor.isEmpty)
              Text(DetailsTranslations.personNoCredits.trOf(context), style: theme.textTheme.bodyMedium)
            else
              SizedBox(
                height: 280,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: person.knownFor.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => _PersonCreditCard(credit: person.knownFor[index], onTap: () => onCreditSelected(person.knownFor[index])),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _PersonPortrait extends StatelessWidget {
  const _PersonPortrait({required this.person, required this.width, required this.height});

  final MediaPerson person;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: width,
        height: height,
        child: person.profileUrl == null
            ? _placeholder()
            : Image.network(person.profileUrl.toString(), fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => _placeholder()),
      ),
    );
  }

  Widget _placeholder() => ColoredBox(
    color: const Color(0x33808080),
    child: Center(
      child: Text(person.name, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
    ),
  );
}

class _PersonFact extends StatelessWidget {
  const _PersonFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: style?.copyWith(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: value, style: style),
        ],
      ),
    );
  }
}

class _PersonCreditCard extends StatelessWidget {
  const _PersonCreditCard({required this.credit, required this.onTap});

  final PersonCredit credit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 128,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 128,
                height: 184,
                child: credit.item.posterUrl == null
                    ? const ColoredBox(color: Color(0x33808080))
                    : Image.network(
                        credit.item.posterUrl.toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const ColoredBox(color: Color(0x33808080)),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(credit.item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
            if (credit.role?.isNotEmpty == true)
              Text(
                credit.role!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

class _PersonError extends StatelessWidget {
  const _PersonError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(DetailsTranslations.personLoadError.trOf(context)),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: Text(DetailsTranslations.retry.trOf(context))),
        ],
      ),
    );
  }
}
