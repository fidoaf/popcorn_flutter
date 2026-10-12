/// A single billed cast member, with the actor's [name], the [character] they
/// play, and an optional [profileUrl] headshot.
final class CastMember {
  const CastMember({required this.name, this.id, this.character, this.profileUrl});

  final String name;

  /// TMDB person ID, `null` when the source does not provide one.
  final int? id;

  /// The character the actor plays. `null` or empty when unknown.
  final String? character;

  /// Headshot image of the actor. `null` when TMDB has no profile photo.
  final Uri? profileUrl;
}
