// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           pagination.d.ts
// Description:    About Pagination Arguments
// Create   Date:  2025-06-22 13:36:59
// Last Modified:  2025-06-22 13:39:26
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

export interface PaginationProps {
  currentPage: number;
  totalPages: number;
  pageSize: number;
  onPrev: () => void;
  onNext: () => void;
  onFirst: () => void;
  onLast: () => void;
  onPageSizeChange: (size: number) => void;
  onPageJump: (page: number) => void;
}
