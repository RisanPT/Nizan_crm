// The phases a company project moves through, by the kind of work its OWNING department does: IT builds software, Marketing runs
// campaigns, every other department (Accounts, Finance, HR, Sales, CRM, Operations, Artist, Fleet, Management…) runs a business
// project. Mirrors the backend's utils/projectPhases.js — keep the two in step.

const Map<String, List<String>> kPhaseSets = {
  'software': ['discovery', 'design', 'development', 'testing', 'deployment', 'maintenance'],
  'campaign': ['research', 'planning', 'production', 'launch', 'review'],
  'standard': ['initiation', 'planning', 'execution', 'review', 'closure'],
};

/// What each phase means, in a few words (shown under the phase menu).
const Map<String, String> kPhaseMeaning = {
  'discovery': 'understand the need',
  'design': 'plan the solution',
  'development': 'build it',
  'testing': 'check it works',
  'deployment': 'go live',
  'maintenance': 'run and improve',
  'research': 'audience, competitors, idea',
  'production': 'make the content',
  'launch': 'publish / run it',
  'initiation': 'agree the goal and scope',
  'planning': 'tasks, people, budget',
  'execution': 'do the work',
  'review': 'check the results',
  'closure': 'hand over and close',
};

// Where each phase sits on one common path (start → plan → do → check → finish): a project that changes department — or one saved
// before departments had their own phases — keeps the equivalent step.
const Map<String, int> _stage = {
  'discovery': 0, 'initiation': 0, 'research': 0,
  'design': 1, 'planning': 1,
  'development': 2, 'execution': 2, 'production': 2,
  'testing': 3, 'review': 3, 'launch': 3,
  'deployment': 4, 'maintenance': 4, 'closure': 4,
};

/// 'software' | 'campaign' | 'standard' for a department's name.
String phaseSetFor(String department) {
  final d = department.trim().toLowerCase();
  if (RegExp(r'\b(it|tech|technology|software)\b').hasMatch(d)) return 'software';
  if (RegExp(r'market|brand|content|media|social').hasMatch(d)) return 'campaign';
  return 'standard';
}

/// The phases for a project owned by [department], in order.
List<String> phasesForDepartment(String department) => kPhaseSets[phaseSetFor(department)]!;

/// "Initiation → Planning → Execution → Review → Closure"
String phasePath(String department) => phasesForDepartment(department).map(phaseLabel).join(' → ');

/// The phase to show / keep for a project owned by [department]: [phase] itself when it is one of that department's, else the
/// equivalent step (Discovery on an Accounts project → Initiation), else the first.
String fitPhase(String phase, String department) {
  final list = phasesForDepartment(department);
  final p = phase.trim().toLowerCase();
  if (list.contains(p)) return p;
  final stage = _stage[p];
  if (stage == null) return list.first;
  for (final x in list) {
    if (_stage[x] == stage) return x;
  }
  final lower = list.where((x) => (_stage[x] ?? 0) < stage);
  return lower.isEmpty ? list.first : lower.last;
}

/// "Initiation"
String phaseLabel(String phase) => phase.isEmpty ? phase : phase[0].toUpperCase() + phase.substring(1);
