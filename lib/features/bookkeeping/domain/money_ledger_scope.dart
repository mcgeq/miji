import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';

enum MoneyLedgerScopeKind { personal, family }

class MoneyLedgerScope {
  const MoneyLedgerScope({required this.ledger, required this.kind});

  final MoneyLedgerEntity ledger;
  final MoneyLedgerScopeKind kind;

  String get ledgerId => ledger.id;

  bool get isPersonal => kind == MoneyLedgerScopeKind.personal;

  bool get isFamily => kind == MoneyLedgerScopeKind.family;

  static MoneyLedgerScope fromLedger(MoneyLedgerEntity ledger) {
    return MoneyLedgerScope(
      ledger: ledger,
      kind: ledger.isFamily
          ? MoneyLedgerScopeKind.family
          : MoneyLedgerScopeKind.personal,
    );
  }
}
