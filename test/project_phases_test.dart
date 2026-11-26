import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/it/domain/project_phases.dart';

// The phases a company project moves through depend on its owning department (mirrors the backend's utils/projectPhases.js).
void main() {
  test('IT keeps the software phases; Marketing has campaign phases; every other department the business ones', () {
    expect(phasesForDepartment('IT'), ['discovery', 'design', 'development', 'testing', 'deployment', 'maintenance']);
    expect(phasesForDepartment('Marketing'), ['research', 'planning', 'production', 'launch', 'review']);
    for (final d in ['Accounts', 'Finance', 'HR', 'Sales', 'CRM', 'Operations', 'Artist', 'Fleet', 'Management', 'Audit', '']) {
      expect(phasesForDepartment(d), ['initiation', 'planning', 'execution', 'review', 'closure'], reason: d);
    }
    expect(phaseSetFor('IT Support'), 'software');
    expect(phaseSetFor('Digital Marketing'), 'campaign');
  });

  test('the path reads in order', () {
    expect(phasePath('Accounts'), 'Initiation → Planning → Execution → Review → Closure');
    expect(phasePath('IT'), 'Discovery → Design → Development → Testing → Deployment → Maintenance');
  });

  test('a phase of the department is kept; another department\'s becomes the equivalent step; unknown → the first', () {
    expect(fitPhase('review', 'Accounts'), 'review');
    expect(['discovery', 'design', 'development', 'testing', 'deployment', 'maintenance'].map((p) => fitPhase(p, 'Accounts')).toList(),
        ['initiation', 'planning', 'execution', 'review', 'closure', 'closure']);
    expect(['discovery', 'design', 'development', 'testing', 'deployment', 'maintenance'].map((p) => fitPhase(p, 'Marketing')).toList(),
        ['research', 'planning', 'production', 'launch', 'review', 'review']);
    expect(['initiation', 'planning', 'execution', 'review', 'closure'].map((p) => fitPhase(p, 'IT')).toList(),
        ['discovery', 'design', 'development', 'testing', 'deployment']);
    expect(fitPhase('', 'HR'), 'initiation');
    expect(fitPhase('party', 'IT'), 'discovery');
  });

  test('every phase says what it means', () {
    for (final list in kPhaseSets.values) {
      for (final p in list) {
        expect(kPhaseMeaning[p], isNotNull, reason: p);
      }
    }
  });
}
