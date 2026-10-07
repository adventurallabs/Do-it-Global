import 'package:flutter/material.dart' show IconData, Icons;

// The centre's Pediatric OT Assessment form, as data. Every section, item and answer the paper form has is listed
// here once; the editor, progress, review, report and PDF are all built from it, so they can't drift apart.
//
// Labels are the form's own wording. Keys are what the database stores; they never change once in use, so a
// re-assessment lines up with the earlier ones item by item.

/// How an answer reads at a glance (the colour of its pill), not what it means clinically.
enum Mood { good, watch, concern, info, neutral }

class Opt {
  final String value, label;
  final Mood mood;
  const Opt(this.value, this.label, [this.mood = Mood.neutral]);
}

class Item {
  final String key, label;
  const Item(this.key, this.label);
}

String? labelOf(List<Opt> options, String? value) {
  for (final o in options) {
    if (o.value == value) return o.label;
  }
  return null;
}

Mood moodOf(List<Opt> options, String? value) {
  for (final o in options) {
    if (o.value == value) return o.mood;
  }
  return Mood.neutral;
}

const notAssessed = Opt('not_assessed', 'Not assessed');

// ---------------------------------------------------------------- answers
class Answers {
  Answers._();
  static const kind = [Opt('initial', 'Initial assessment'), Opt('reassessment', 'Re-assessment'), Opt('follow_up', 'Follow-up assessment')];
  static const gender = [Opt('male', 'Male'), Opt('female', 'Female'), Opt('other', 'Other')];
  static const handDominance = [
    Opt('right', 'Right'),
    Opt('left', 'Left'),
    Opt('ambidextrous', 'Ambidextrous'),
    Opt('not_established', 'Not established'),
    notAssessed,
  ];
  static const yesNo = [Opt('yes', 'Yes'), Opt('no', 'No')];
  static const senses = [Opt('normal', 'Normal', Mood.good), Opt('concern', 'Concern', Mood.watch), Opt('impaired', 'Impaired', Mood.concern), notAssessed];
  static const milestone = [Opt('present', 'Present', Mood.good), Opt('absent', 'Absent', Mood.concern), Opt('delayed', 'Delayed', Mood.watch), notAssessed];
  static const school = [
    Opt('regular', 'Regular'),
    Opt('regular_integrated', 'Regular Integrated'),
    Opt('special', 'Special'),
    Opt('not_school_going', 'Not School Going'),
  ];
  static const playTypes = [
    Opt('solitary', 'Solitary'),
    Opt('parallel', 'Parallel'),
    Opt('associative', 'Associative'),
    Opt('cooperative', 'Cooperative'),
    Opt('games_with_rules', 'Games with Rules'),
  ];
  static const playMethods = [Opt('functional', 'Functional Play'), Opt('pretend', 'Pretend Play'), Opt('sensorimotor', 'Sensorimotor')];
  static const skill = [Opt('present', 'Present', Mood.good), Opt('absent', 'Absent', Mood.concern), Opt('emerging', 'Emerging / Developing', Mood.info)];
  static const group = [
    Opt('alone', 'Prefers to be alone'),
    Opt('some', 'Plays well with others to some extent'),
    Opt('with_others', 'Plays with others'),
  ];
  static const defeat = [
    Opt('age_appropriate', 'Age Appropriate', Mood.good),
    Opt('age_inappropriate', 'Age Inappropriate', Mood.concern),
    Opt('needs_support', 'Needs Support', Mood.watch),
    notAssessed,
  ];
  static const behaviour = [Opt('present', 'Present', Mood.watch), Opt('absent', 'Absent', Mood.good), notAssessed];
  static const severity = [Opt('mild', 'Mild', Mood.info), Opt('moderate', 'Moderate', Mood.watch), Opt('severe', 'Severe', Mood.concern)];
  static const sensory = [Opt('no_concern', 'No Concern', Mood.good), Opt('concern', 'Concern Present', Mood.watch), notAssessed];
  static const posture = [Opt('normal', 'Normal', Mood.good), Opt('abnormal', 'Abnormal', Mood.concern), notAssessed];
  static const reflex = [
    Opt('normal', 'Normal', Mood.good),
    Opt('absent', 'Absent', Mood.watch),
    Opt('retained', 'Present / Retained', Mood.info),
    Opt('exaggerated', 'Exaggerated', Mood.concern),
    notAssessed,
  ];
  static const hand = [Opt('present', 'Present', Mood.good), Opt('emerging', 'Emerging', Mood.info), Opt('absent', 'Absent', Mood.concern), notAssessed];
  static const adl = [
    Opt('independent', 'Independent', Mood.good),
    Opt('independent_difficulty', 'Independent with Difficulty', Mood.info),
    Opt('needs_assistance', 'Needs Assistance', Mood.watch),
    Opt('dependent', 'Dependent', Mood.concern),
    Opt('not_applicable', 'Not Applicable'),
    notAssessed,
  ];
  static const goalStatus = [
    Opt('not_started', 'Not Started'),
    Opt('in_progress', 'In Progress', Mood.info),
    Opt('achieved', 'Achieved', Mood.good),
    Opt('modified', 'Modified', Mood.watch),
  ];
  static const status = [Opt('draft', 'Draft'), Opt('in_progress', 'In progress', Mood.info), Opt('completed', 'Completed', Mood.good), Opt('archived', 'Archived')];
}

// ---------------------------------------------------------------- items
class Items {
  Items._();
  static const senses = [Item('vision', 'Vision'), Item('hearing', 'Hearing'), Item('speech', 'Speech')];
  static const milestones = [
    Item('head_control', 'Head Control'),
    Item('roll_over', 'Roll Over'),
    Item('unsupported_sitting', 'Unsupported Sitting'),
    Item('crawling', 'Crawling'),
    Item('standing', 'Standing'),
    Item('walking', 'Walking'),
    Item('jumping', 'Jumping'),
    Item('stair_climbing', 'Stair Climbing'),
    Item('cycle_pedaling', 'Cycle Pedaling'),
  ];
  static const playSkills = [Item('name_calling', 'Name Calling'), Item('turn_taking', 'Turn Taking'), Item('sharing', 'Sharing')];
  static const handleDefeat = Item('handle_defeat', 'Ability to Handle Defeat / Loss');
  static const behaviour = [
    Item('self_injury', 'Self Injury'),
    Item('harming_others', 'Harming Others and Surroundings'),
    Item('inattentive', 'Inattentive'),
    Item('hyperactive', 'Hyperactive'),
    Item('nail_biting', 'Nail Biting'),
    Item('drowsy', 'Drowsy'),
    Item('impulsive', 'Impulsive'),
    Item('tantrums', 'Tantrums'),
    Item('hand_flapping', 'Hand Flapping / Fidgeting'),
    Item('teeth_grinding', 'Teeth Grinding'),
    Item('repetitive', 'Repetitive Sounds / Movement'),
    Item('stimming', 'Stimming'),
    Item('spinning', 'Spinning'),
  ];
  static const sensory = [
    Item('visual', 'Visual'),
    Item('proprioceptive', 'Proprioceptive'),
    Item('vestibular', 'Vestibular'),
    Item('tactile', 'Tactile'),
    Item('gustatory', 'Gustatory'),
    Item('olfactory', 'Olfactory'),
    Item('auditory', 'Auditory'),
  ];
  static const posture = [Item('standing', 'Standing'), Item('walking', 'Walking'), Item('sitting', 'Sitting')];
  static const primitiveReflexes = [
    Item('rooting', 'Rooting'),
    Item('sucking', 'Sucking'),
    Item('biting', 'Biting'),
    Item('grasp', 'Grasp'),
    Item('stepping', 'Stepping'),
    Item('placing', 'Placing'),
    Item('galant', 'Galant'),
    Item('moro', 'Moro'),
  ];
  static const otherReflexes = [
    Item('biceps', 'Biceps'),
    Item('triceps', 'Triceps'),
    Item('supinator', 'Supinator'),
    Item('knee', 'Knee'),
    Item('ankle', 'Ankle'),
    Item('babinski', 'Babinski'),
  ];
  static const upperJoints = [Item('shoulder', 'Shoulder'), Item('elbow', 'Elbow'), Item('forearm', 'Forearm'), Item('wrist', 'Wrist'), Item('fingers', 'Fingers')];
  static const lowerJoints = [Item('hip', 'Hip'), Item('knee', 'Knee'), Item('ankle', 'Ankle')];
  static const sides = [Item('right', 'Right'), Item('left', 'Left')];
  static const adl = [
    Item('feeding', 'Feeding'),
    Item('toileting', 'Toileting'),
    Item('bladder', 'Bladder Management'),
    Item('bowel', 'Bowel Management'),
    Item('dressing_upper', 'Dressing / Undressing — Upper Body'),
    Item('dressing_lower', 'Dressing / Undressing — Lower Body'),
    Item('grooming', 'Grooming'),
    Item('bathing', 'Bathing'),
    Item('transfers', 'Transfers'),
    Item('locomotion', 'Locomotion'),
    Item('psychosocial', 'Psychosocial Problems'),
  ];

  /// An "Others" ADL: its key starts with this; the therapist names it.
  static const adlOtherPrefix = 'other_';
}

/// Hand function, in the form's order. A group with one item ("Reach") is assessed as a whole; the others list
/// the patterns seen, each rated on its own so a later assessment can show e.g. Dynamic Tripod: Absent → Emerging.
class HandGroup {
  final String key, title;
  final List<Item> items;
  const HandGroup(this.key, this.title, this.items);
  bool get single => items.length == 1;
}

const handGroups = [
  HandGroup('reach', 'Reach', [Item('reach', 'Reach')]),
  HandGroup('grasp', 'Grasp', [Item('grasp_hook', 'Hook'), Item('grasp_cylindrical', 'Cylindrical'), Item('grasp_spherical', 'Spherical'), Item('grasp_pincer', 'Pincer')]),
  HandGroup('prehension', 'Prehension', [
    Item('prehension_pulp_to_pulp', 'Pulp to Pulp'),
    Item('prehension_tip_to_tip', 'Tip to Tip'),
    Item('prehension_tripod', 'Tripod'),
    Item('prehension_pad_to_pad', 'Pad to Pad'),
  ]),
  HandGroup('non_prehension', 'Non-Prehension', [Item('non_prehension_clapping', 'Clapping'), Item('non_prehension_pushing', 'Pushing'), Item('non_prehension_pulling', 'Pulling')]),
  HandGroup('release', 'Release', [Item('release', 'Release')]),
  HandGroup('in_hand', 'In-Hand Manipulation', [
    Item('in_hand_translation', 'Translation'),
    Item('in_hand_shifting', 'Shifting'),
    Item('in_hand_cascading', 'Cascading'),
    Item('in_hand_rotation', 'Rotation'),
  ]),
  HandGroup('pencil', 'Pencil Grasp', [
    Item('pencil_palmar', 'Palmar'),
    Item('pencil_digital_pronate', 'Digital Pronate'),
    Item('pencil_quadrupod', 'Quadrupod / Digital'),
    Item('pencil_static_tripod', 'Static Tripod'),
    Item('pencil_dynamic_tripod', 'Dynamic Tripod'),
  ]),
  HandGroup('pinch', 'Pinch', [Item('pinch', 'Pinch')]),
];

/// Quick answers offered beside the AROM / PROM boxes. The box takes any text (degrees, "Limited at end range").
const romQuick = ['WFL', 'Limited', 'Full'];

// ---------------------------------------------------------------- sections
class SectionDef {
  final String id, title, short;
  final IconData icon;
  const SectionDef(this.id, this.title, this.short, this.icon);
}

const sections = [
  SectionDef('demographics', 'Demographic Data', 'Demographics', Icons.badge_outlined),
  SectionDef('medical', 'Medical History', 'Medical History', Icons.medical_information_outlined),
  SectionDef('senses', 'Special Senses', 'Special Senses', Icons.visibility_outlined),
  SectionDef('development', 'Developmental History', 'Development', Icons.child_care_rounded),
  SectionDef('education', 'Educational History', 'Education', Icons.school_outlined),
  SectionDef('play', 'Play', 'Play', Icons.toys_outlined),
  SectionDef('screen', 'Screen Time', 'Screen Time', Icons.devices_other_outlined),
  SectionDef('behaviour', 'Behavioural Assessment', 'Behaviour', Icons.psychology_outlined),
  SectionDef('sensory', 'Sensory Assessment', 'Sensory', Icons.touch_app_outlined),
  SectionDef('posture', 'Posture', 'Posture', Icons.accessibility_new_rounded),
  SectionDef('reflexes', 'Reflexes', 'Reflexes', Icons.bolt_outlined),
  SectionDef('rom', 'Range of Motion / Muscle Strength', 'ROM & Strength', Icons.fitness_center_rounded),
  SectionDef('hand', 'Hand Function', 'Hand Function', Icons.back_hand_outlined),
  SectionDef('adl', 'ADL Evaluation', 'ADL', Icons.restaurant_outlined),
  SectionDef('plan', 'Problems Identified & Treatment Plan', 'Treatment Plan', Icons.assignment_outlined),
  SectionDef('goals', 'Goals', 'Goals', Icons.flag_outlined),
  SectionDef('approaches', 'Approaches Used', 'Approaches', Icons.lightbulb_outline_rounded),
  SectionDef('home', 'Home Program', 'Home Program', Icons.home_outlined),
];

int sectionIndex(String id) {
  final i = sections.indexWhere((s) => s.id == id);
  return i < 0 ? 0 : i;
}
