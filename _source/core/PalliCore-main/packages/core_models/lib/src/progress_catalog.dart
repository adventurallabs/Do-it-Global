import 'growth.dart';
import 'progress_template.dart';

/// Ready-made presets so a teacher picks instead of types. Mirrors the
/// `GradeCatalog` / `SubjectCatalog` style: a fixed suggested list, with
/// teacher-created templates layered on top (never a strict enum).
class ProgressCatalog {
  static const _obsPositive = ObservationTone.positive;
  static const _obsAttention = ObservationTone.attention;

  static ProgressTemplate _t(ProgressKind kind, String category, String title,
          [String body = '', ObservationTone tone = ObservationTone.positive]) =>
      ProgressTemplate(
        id: 'builtin:${kind.name}:$title',
        kind: kind,
        title: title,
        category: category,
        body: body,
        tone: tone,
      );

  // --- stars ----------------------------------------------------------------

  static final List<ProgressTemplate> stars = [
    for (final (cat, title) in const [
      ('Kindness', 'Helping a classmate'),
      ('Kindness', 'Being kind and caring'),
      ('Kindness', 'Sharing with others'),
      ('Learning', 'Great answer in class'),
      ('Learning', 'Asking a thoughtful question'),
      ('Learning', 'Excellent homework'),
      ('Learning', 'Big improvement'),
      ('Learning', 'Neat and tidy work'),
      ('Character', 'Showing leadership'),
      ('Character', 'Honesty'),
      ('Character', 'Good discipline'),
      ('Character', 'On time, every day'),
      ('Teamwork', 'Great teamwork'),
      ('Teamwork', 'Cleaning up the class'),
      ('Creativity', 'Creative idea'),
      ('Creativity', 'Wonderful artwork'),
    ])
      _t(ProgressKind.star, cat, title),
  ];

  // --- activities -------------------------------------------------------------

  static final List<ProgressTemplate> activities = [
    for (final (cat, title) in const [
      ('Sports', 'Sports day'),
      ('Sports', 'Running race'),
      ('Sports', 'Football match'),
      ('Sports', 'Yoga session'),
      ('Sports', 'Chess tournament'),
      ('Arts', 'Drawing competition'),
      ('Arts', 'Craft work'),
      ('Arts', 'Dance performance'),
      ('Arts', 'Music performance'),
      ('Academic', 'Quiz competition'),
      ('Academic', 'Science exhibition'),
      ('Academic', 'Spelling bee'),
      ('Academic', 'Maths olympiad'),
      ('Academic', 'Elocution / speech'),
      ('Cultural', 'Annual day'),
      ('Cultural', 'Drama / skit'),
      ('Cultural', 'Festival celebration'),
      ('Cultural', 'Independence Day programme'),
      ('Clubs', 'Eco club'),
      ('Clubs', 'Cleanliness drive'),
      ('Clubs', 'Tree planting'),
      ('Clubs', 'Field trip'),
      ('Clubs', 'Library reading'),
    ])
      _t(ProgressKind.activity, cat, title),
  ];

  /// Quick result chips for an activity (optional).
  static const activityResults = [
    'Participated',
    'Winner',
    'Runner-up',
    'Third place',
    'Special mention',
  ];

  // --- observations -----------------------------------------------------------

  static final List<ProgressTemplate> observations = [
    _t(ProgressKind.observation, 'Participation', 'Active in class',
        'Participates actively and asks thoughtful questions in class.', _obsPositive),
    _t(ProgressKind.observation, 'Behaviour', 'Helpful to classmates',
        'Is always ready to help classmates and works well with others.', _obsPositive),
    _t(ProgressKind.observation, 'Learning', 'Great improvement',
        'Has shown clear improvement in recent weeks. Keep encouraging at home!', _obsPositive),
    _t(ProgressKind.observation, 'Work habits', 'Neat, complete work',
        'Completes class work neatly and on time.', _obsPositive),
    _t(ProgressKind.observation, 'Behaviour', 'Respectful and polite',
        'Is respectful and polite with teachers and classmates.', _obsPositive),
    _t(ProgressKind.observation, 'Learning', 'Curious learner',
        'Shows real curiosity and enjoys exploring new topics.', _obsPositive),
    _t(ProgressKind.observation, 'Participation', 'Confident speaker',
        'Speaks confidently in front of the class.', _obsPositive),
    _t(ProgressKind.observation, 'Participation', 'Needs to focus more',
        'Gets distracted during lessons. A little help building focus at home would go a long way.',
        _obsAttention),
    _t(ProgressKind.observation, 'Work habits', 'Homework often incomplete',
        'Homework has been incomplete a few times recently. Please check the diary daily.',
        _obsAttention),
    _t(ProgressKind.observation, 'Learning', 'Reading practice needed',
        'Would benefit from 15 minutes of reading aloud at home every day.', _obsAttention),
    _t(ProgressKind.observation, 'Work habits', 'Handwriting practice',
        'Handwriting needs some practice to become clearer.', _obsAttention),
    _t(ProgressKind.observation, 'Wellbeing', 'Seems tired lately',
        'Has seemed tired or unwell in class recently. Just letting you know.', _obsAttention),
  ];

  // --- skills -----------------------------------------------------------------

  static final List<ProgressTemplate> skills = [
    for (final (cat, title) in const [
      ('Communication', 'Speaking'),
      ('Communication', 'Listening'),
      ('Communication', 'Reading'),
      ('Communication', 'Writing'),
      ('Thinking', 'Problem solving'),
      ('Thinking', 'Creativity'),
      ('Thinking', 'Curiosity'),
      ('Social', 'Teamwork'),
      ('Social', 'Leadership'),
      ('Social', 'Empathy'),
      ('Personal', 'Discipline'),
      ('Personal', 'Confidence'),
      ('Personal', 'Time management'),
      ('Personal', 'Neatness'),
      ('Physical', 'Fitness'),
      ('Physical', 'Motor skills'),
    ])
      _t(ProgressKind.skill, cat, title),
  ];

  static List<ProgressTemplate> builtInsFor(ProgressKind kind) => switch (kind) {
        ProgressKind.star => stars,
        ProgressKind.activity => activities,
        ProgressKind.observation => observations,
        ProgressKind.skill => skills,
      };

  /// Category suggestions for the "create your own" form.
  static List<String> categoriesFor(ProgressKind kind) {
    final seen = <String>{};
    return [
      for (final t in builtInsFor(kind))
        if (seen.add(t.category)) t.category,
    ];
  }
}
