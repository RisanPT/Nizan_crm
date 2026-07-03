with open('lib/core/routing/app_router.dart', 'r') as f:
    content = f.read()

import_statement = "import '../../presentation/screens/accounts_invoices_screen.dart';\n"
if "accounts_invoices_screen.dart" not in content:
    content = content.replace(
        "import '../../presentation/screens/accounts_budget_screen.dart';",
        "import '../../presentation/screens/accounts_budget_screen.dart';\n" + import_statement
    )

route_statement = """        GoRoute(
          path: 'invoices',
          builder: (context, state) => const MainLayout(
            child: AccountsInvoicesScreen(),
          ),
        ),"""

if "path: 'invoices'," not in content:
    content = content.replace(
        "path: 'budget',",
        "path: 'budget',\n        ),\n" + route_statement + "\n        // "
    )
    # The replace above is a bit risky. Let's write a smarter Python replacement.

with open('lib/core/routing/app_router.dart', 'w') as f:
    f.write(content)
