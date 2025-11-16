import { MoneyDb } from '@/services/money/money';
import { Lg } from '@/utils/debugLog';
import type {
  FamilyLedger,
  FamilyMember,
  SplitMember,
  Transaction,
  TransactionCreate,
} from '@/schema/money';

/**
 * 交易与账本关联的 Composable
 */
export function useTransactionLedgerLink() {
  const availableLedgers = ref<FamilyLedger[]>([]);
  const selectedLedgers = ref<string[]>([]);
  const availableMembers = ref<SplitMember[]>([]);
  const selectedMembers = ref<string[]>([]);
  const loading = ref(false);

  /**
   * 加载可用的账本列表
   */
  async function loadAvailableLedgers() {
    try {
      availableLedgers.value = await MoneyDb.listFamilyLedgers();
      Lg.d('useTransactionLedgerLink', `Loaded ${availableLedgers.value.length} ledgers`);
    } catch (error) {
      Lg.e('useTransactionLedgerLink', 'Failed to load ledgers:', error);
      availableLedgers.value = [];
    }
  }

  /**
   * 加载可用的成员列表（根据选中的账本）
   */
  async function loadAvailableMembers() {
    try {
      // 如果没有选择账本，清空成员列表
      if (selectedLedgers.value.length === 0) {
        availableMembers.value = [];
        return;
      }

      // 根据选中的账本获取成员
      const members = await getMembersByLedgers(selectedLedgers.value);
      availableMembers.value = members;
      Lg.d('useTransactionLedgerLink', `Loaded ${availableMembers.value.length} members for selected ledgers`);
    } catch (error) {
      Lg.e('useTransactionLedgerLink', 'Failed to load members:', error);
      availableMembers.value = [];
    }
  }

  /**
   * 根据账户推荐账本
   */
  async function suggestLedgersByAccount(accountSerialNum: string): Promise<FamilyLedger[]> {
    try {
      // 查询账户关联的账本
      const accountLedgers = await MoneyDb.listFamilyLedgerAccounts();
      const relatedLedgerIds = accountLedgers
        .filter(al => al.accountSerialNum === accountSerialNum)
        .map(al => al.familyLedgerSerialNum);

      // 获取账本详情
      const ledgerPromises = relatedLedgerIds.map(id => MoneyDb.getFamilyLedger(id));
      const ledgers = await Promise.all(ledgerPromises);

      return ledgers.filter(l => l !== null) as FamilyLedger[];
    } catch (error) {
      Lg.e('useTransactionLedgerLink', 'Failed to suggest ledgers:', error);
      return [];
    }
  }

  /**
   * 将 FamilyMember 转换为 SplitMember
   */
  function convertToSplitMember(member: FamilyMember): SplitMember {
    return {
      serialNum: member.serialNum,
      name: member.name,
      avatar: member.avatar,
    };
  }

  /**
   * 根据账本获取成员列表
   */
  async function getMembersByLedgers(ledgerSerialNums: string[]): Promise<SplitMember[]> {
    try {
      if (ledgerSerialNums.length === 0) return [];

      // 获取所有账本的成员关联
      const allLedgerMembers = await MoneyDb.listFamilyLedgerMembers();

      // 筛选出选中账本的成员
      const memberIds = new Set<string>();
      allLedgerMembers
        .filter(lm => ledgerSerialNums.includes(lm.familyLedgerSerialNum))
        .forEach(lm => memberIds.add(lm.familyMemberSerialNum));

      // 获取成员详情
      const memberPromises = Array.from(memberIds).map(id => MoneyDb.getFamilyMember(id));
      const members = await Promise.all(memberPromises);

      return members
        .filter(m => m !== null)
        .map(m => convertToSplitMember(m as FamilyMember));
    } catch (error) {
      Lg.e('useTransactionLedgerLink', 'Failed to get members:', error);
      return [];
    }
  }

  /**
   * 创建交易并关联到账本和成员
   */
  async function createTransactionWithLinks(
    transactionData: TransactionCreate,
    ledgerIds: string[],
    memberIds: string[] = [],
  ): Promise<Transaction> {
    loading.value = true;
    try {
      // 1. 创建交易
      const transaction = await MoneyDb.createTransaction(transactionData);
      Lg.d('useTransactionLedgerLink', 'Transaction created:', transaction.serialNum);

      // 2. 关联到账本
      if (ledgerIds.length > 0) {
        const associations = ledgerIds.map(ledgerId => ({
          familyLedgerSerialNum: ledgerId,
          transactionSerialNum: transaction.serialNum,
        }));
        await MoneyDb.batchCreateFamilyLedgerTransactions(associations);
        Lg.d('useTransactionLedgerLink', `Linked to ${ledgerIds.length} ledgers`);
      }

      // 3. 更新交易的分摊成员字段
      if (memberIds.length > 0) {
        // 获取成员详情并转换为 SplitMember
        const memberPromises = memberIds.map(id => MoneyDb.getFamilyMember(id));
        const members = (await Promise.all(memberPromises))
          .filter(m => m !== null)
          .map(m => convertToSplitMember(m as FamilyMember));

        const updatedTransaction = await MoneyDb.updateTransaction(transaction.serialNum, {
          splitMembers: members,
        });
        Lg.d('useTransactionLedgerLink', `Linked to ${memberIds.length} members`);
        return updatedTransaction;
      }

      return transaction;
    } catch (error) {
      Lg.e('useTransactionLedgerLink', 'Failed to create transaction with links:', error);
      throw error;
    } finally {
      loading.value = false;
    }
  }

  /**
   * 更新交易的账本和成员关联
   */
  async function updateTransactionLinks(
    transactionSerialNum: string,
    ledgerIds: string[],
    memberIds: string[] = [],
  ): Promise<void> {
    loading.value = true;
    try {
      // 1. 更新账本关联
      await MoneyDb.updateTransactionLedgers(transactionSerialNum, ledgerIds);
      Lg.d('useTransactionLedgerLink', `Updated ledger links for transaction ${transactionSerialNum}`);

      // 2. 更新成员关联
      if (memberIds.length > 0) {
        // 获取成员详情并转换为 SplitMember
        const memberPromises = memberIds.map(id => MoneyDb.getFamilyMember(id));
        const members = (await Promise.all(memberPromises))
          .filter(m => m !== null)
          .map(m => convertToSplitMember(m as FamilyMember));

        await MoneyDb.updateTransaction(transactionSerialNum, {
          splitMembers: members,
        });
        Lg.d('useTransactionLedgerLink', `Updated member links for transaction ${transactionSerialNum}`);
      }
    } catch (error) {
      Lg.e('useTransactionLedgerLink', 'Failed to update transaction links:', error);
      throw error;
    } finally {
      loading.value = false;
    }
  }

  /**
   * 获取交易的当前关联
   */
  async function getTransactionLinks(transactionSerialNum: string): Promise<{
    ledgers: FamilyLedger[];
    members: SplitMember[];
  }> {
    try {
      // 1. 获取账本关联
      const ledgerAssociations = await MoneyDb.listFamilyLedgerTransactionsByTransaction(
        transactionSerialNum,
      );
      const ledgerIds = ledgerAssociations.map(a => a.familyLedgerSerialNum);
      const ledgerPromises = ledgerIds.map(id => MoneyDb.getFamilyLedger(id));
      const ledgers = (await Promise.all(ledgerPromises)).filter(l => l !== null) as FamilyLedger[];

      // 2. 获取成员关联
      const transaction = await MoneyDb.getTransaction(transactionSerialNum);
      let members: SplitMember[] = [];

      if (transaction?.splitMembers && Array.isArray(transaction.splitMembers)) {
        members = transaction.splitMembers;
      }

      return { ledgers, members };
    } catch (error) {
      Lg.e('useTransactionLedgerLink', 'Failed to get transaction links:', error);
      return { ledgers: [], members: [] };
    }
  }

  /**
   * 智能推荐：根据账户和历史记录推荐账本和成员
   */
  async function getSmartSuggestions(accountSerialNum: string): Promise<{
    suggestedLedgers: FamilyLedger[];
    suggestedMembers: SplitMember[];
  }> {
    try {
      // 1. 根据账户推荐账本
      const suggestedLedgers = await suggestLedgersByAccount(accountSerialNum);

      // 2. 根据推荐的账本获取成员
      const ledgerIds = suggestedLedgers.map(l => l.serialNum);
      const suggestedMembers = await getMembersByLedgers(ledgerIds);

      return { suggestedLedgers, suggestedMembers };
    } catch (error) {
      Lg.e('useTransactionLedgerLink', 'Failed to get smart suggestions:', error);
      return { suggestedLedgers: [], suggestedMembers: [] };
    }
  }

  return {
    // 状态
    availableLedgers,
    selectedLedgers,
    availableMembers,
    selectedMembers,
    loading,

    // 方法
    loadAvailableLedgers,
    loadAvailableMembers,
    suggestLedgersByAccount,
    getMembersByLedgers,
    createTransactionWithLinks,
    updateTransactionLinks,
    getTransactionLinks,
    getSmartSuggestions,
  };
}
