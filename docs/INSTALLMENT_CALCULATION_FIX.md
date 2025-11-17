# Installment Calculation Error Fix

## Issue
Frontend error when calculating installment amounts:
```
SystemError: System error: invalid args `data` for command `installment_calculate`: missing field `total_periods`
```

## Root Cause
The `total_periods` field was being sent as `undefined` or `null` instead of a valid number when:
1. Form initialization didn't properly convert backend values to numbers
2. Validation didn't catch `undefined/null` values (only checked `<= 0`)
3. When spreading transaction objects, numeric fields might not be present in the backend response

## Backend Requirements
The `installment_calculate` command expects:
```rust
pub struct InstallmentCalculationRequest {
    pub total_amount: Decimal,
    pub total_periods: i32,      // Must be a valid i32, not undefined/null
    pub first_due_date: NaiveDate,
}
```

## Frontend Type
```typescript
export interface InstallmentCalculationRequest {
  total_amount: number;
  total_periods: number;          // Must be a valid number
  first_due_date: string;         // YYYY-MM-DD format
}
```

## Solutions Applied

### 1. Enhanced Validation in `calculateInstallmentFromBackend()` (Line 174-185)
**Before:**
```typescript
if (!form.value.isInstallment || form.value.totalPeriods <= 0 || form.value.amount <= 0) {
  return;
}
```

**After:**
```typescript
// More strict validation: ensure all required fields are valid
if (
  !form.value.isInstallment
  || !form.value.totalPeriods          // Check for undefined/null
  || form.value.totalPeriods <= 0
  || !form.value.amount
  || form.value.amount <= 0
) {
  installmentCalculationResult.value = null;
  return;
}
```

### 2. Explicit Number Conversion in Request (Line 190-192)
**Before:**
```typescript
const request: InstallmentCalculationRequest = {
  total_amount: form.value.amount,
  total_periods: form.value.totalPeriods,  // Might be undefined
  first_due_date: ...,
};
```

**After:**
```typescript
const request: InstallmentCalculationRequest = {
  total_amount: Number(form.value.amount),
  total_periods: Number(form.value.totalPeriods),  // Ensure it's a number
  first_due_date: ...,
};
```

### 3. Safe Form Initialization (Line 83-100)
**Before:**
```typescript
const form = ref<Transaction>({
  ...trans,
  // 分期相关字段
  isInstallment: false,
  firstDueDate: undefined,
  totalPeriods: 0,
  // ...
});
```

**After:**
```typescript
const form = ref<Transaction>({
  ...trans,
  // 分期相关字段
  isInstallment: trans.isInstallment || false,
  firstDueDate: trans.firstDueDate || undefined,
  totalPeriods: Number(trans.totalPeriods) || 0,        // Safe conversion
  remainingPeriods: Number(trans.remainingPeriods) || 0,
  installmentAmount: Number(trans.installmentAmount) || 0,
  remainingPeriodsAmount: Number(trans.remainingPeriodsAmount) || 0,
  installmentPlanSerialNum: trans.installmentPlanSerialNum || null,
});
```

### 4. Transaction Watcher Update (Line 857-872)
**Added:**
```typescript
form.value = {
  ...getDefaultTransaction(props.type, props.accounts),
  ...transaction,
  // ... other fields ...
  // 确保分期相关字段都是有效的数字
  totalPeriods: Number(transaction.totalPeriods) || 0,
  remainingPeriods: Number(transaction.remainingPeriods) || 0,
  installmentAmount: Number(transaction.installmentAmount) || 0,
  remainingPeriodsAmount: Number(transaction.remainingPeriodsAmount) || 0,
};
```

## Testing Checklist
- [x] Create transaction with installment enabled
- [x] Verify totalPeriods is set to non-zero value
- [x] Calculate installment amounts successfully
- [x] Edit existing installment transaction
- [x] Toggle installment on/off
- [x] Change totalPeriods value

## Files Modified
- `src/features/money/components/TransactionModal.vue`

## Related
- Backend Command: `crates/money/src/command.rs::installment_calculate`
- Backend DTO: `crates/money/src/dto/installment.rs::InstallmentCalculationRequest`
- Frontend Schema: `src/schema/money/transaction.ts::InstallmentCalculationRequest`

## Prevention
All numeric fields from backend responses should be explicitly converted using `Number()` with fallback values:
```typescript
fieldName: Number(backendValue) || defaultValue
```

This ensures:
1. `undefined` → `defaultValue`
2. `null` → `defaultValue`
3. String numbers → parsed number
4. Invalid values → `defaultValue`
