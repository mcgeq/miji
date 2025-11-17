# Split Records CHECK Constraint Fix

## Issue
Database error when creating split records: `CHECK constraint failed: status`

## Root Cause
The code was using incorrect case for database values:
- **Status**: Code used `"PENDING"` but database expects `"Pending"`
- **SplitType**: Frontend sends `"PERCENTAGE"` but database expects `"Percentage"`

## Database CHECK Constraints

### Status Field (line 73-76 in migration)
```rust
.check(
    Expr::col(SplitRecords::Status)
        .is_in(vec!["Pending", "Confirmed", "Paid", "Cancelled"]),
)
```

Valid values: `"Pending"`, `"Confirmed"`, `"Paid"`, `"Cancelled"`

### SplitType Field (line 82-85 in migration)
```rust
.check(
    Expr::col(SplitRecords::SplitType)
        .is_in(vec!["Equal", "Percentage", "FixedAmount", "Weighted"]),
)
```

Valid values: `"Equal"`, `"Percentage"`, `"FixedAmount"`, `"Weighted"`

## Solution

### 1. Fixed Status Value
Changed from `"PENDING"` to `"Pending"` on line 32 of `split_record.rs`:
```rust
status: Set("Pending".to_string()),
```

### 2. Added Normalization Function
Created `normalize_split_type()` function to convert frontend values to database format:
```rust
fn normalize_split_type(split_type: &str) -> String {
    match split_type.to_uppercase().as_str() {
        "EQUAL" => "Equal".to_string(),
        "PERCENTAGE" => "Percentage".to_string(),
        "FIXEDAMOUNT" | "FIXED_AMOUNT" => "FixedAmount".to_string(),
        "WEIGHTED" => "Weighted".to_string(),
        _ => split_type.to_string(),
    }
}
```

### 3. Updated split_record Creation
Line 33 now normalizes the split_type:
```rust
split_type: Set(normalize_split_type(&split_config.split_type)),
```

## Files Modified
- `src-tauri/crates/money/src/services/split_record.rs`

## Testing
1. Build the project: `cargo build`
2. Create a transaction with split configuration
3. Verify split_records are created successfully
4. Check both status and split_type values in database

## Related
- Migration: `m20251112_000004_create_split_records_table.rs`
- Entity: `entity/src/split_records.rs`
- Service: `crates/money/src/services/split_record.rs`
