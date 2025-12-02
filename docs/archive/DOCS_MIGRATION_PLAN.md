# 文档迁移方案

**创建时间**: 2025-11-16  
**目标**: 整理项目根目录下的md文件，建立清晰的文档结构

---

## 📁 目录结构设计

```
项目根目录/
├── README.md                          # 项目说明（保留）
├── README-ZH-CN.md                    # 中文说明（保留）
├── FAMILY_LEDGER_PLAN.md             # 总体规划（保留 - 核心文档）
│
├── docs/
│   ├── development/                   # 开发文档
│   │   ├── DEVELOPMENT_PROGRESS.md
│   │   ├── LONG_TERM_ROADMAP.md
│   │   └── FAMILY_LEDGER_PLAN_UPDATE.md
│   │
│   ├── reports/                       # 完成报告
│   │   ├── phase2/
│   │   │   └── PHASE2_COMPLETION_REPORT.md
│   │   ├── phase3/
│   │   │   └── PHASE3_FINAL_SUMMARY.md
│   │   ├── phase4/
│   │   │   └── PHASE4_MEMBER_SYSTEM_COMPLETE.md
│   │   ├── phase5/
│   │   │   └── PHASE5_SPLIT_RULES_COMPLETE.md
│   │   ├── phase6/
│   │   │   └── PHASE6_CHARTS_COMPLETE.md
│   │   └── backend/
│   │       └── BACKEND_IMPLEMENTATION_COMPLETE.md
│   │
│   ├── analysis/                      # 技术分析
│   │   ├── PHASE4_MEMBER_SYSTEM_ANALYSIS.md
│   │   ├── PHASE5_SPLIT_RULES_ANALYSIS.md
│   │   └── PHASE6_CHARTS_ANALYSIS.md
│   │
│   ├── guides/                        # 技术指南
│   │   ├── PHASE3_INTEGRATION_GUIDE.md
│   │   ├── PHASE3_README.md
│   │   ├── BACKEND_RUST_IMPLEMENTATION.md
│   │   ├── API_INTEGRATION_CHECKLIST.md
│   │   └── QUICK_START_UI_VALIDATION.md
│   │
│   └── archive/                       # 归档文档
│       ├── PHASE_FILES_CLEANUP_REPORT.md
│       └── BACKEND_FILES_CLEANUP_REPORT.md
│
└── (database文档已在 docs/database/)
```

---

## 📋 文件分类清单

### 保留在根目录 (3个)
1. ✅ README.md - 项目主说明
2. ✅ README-ZH-CN.md - 中文说明
3. ✅ FAMILY_LEDGER_PLAN.md - 核心规划文档

### 迁移到 docs/development/ (3个)
4. 📁 DEVELOPMENT_PROGRESS.md
5. 📁 LONG_TERM_ROADMAP.md
6. 📁 FAMILY_LEDGER_PLAN_UPDATE.md

### 迁移到 docs/reports/ (6个)
7. 📁 PHASE2_COMPLETION_REPORT.md → docs/reports/phase2/
8. 📁 PHASE3_FINAL_SUMMARY.md → docs/reports/phase3/
9. 📁 PHASE4_MEMBER_SYSTEM_COMPLETE.md → docs/reports/phase4/
10. 📁 PHASE5_SPLIT_RULES_COMPLETE.md → docs/reports/phase5/
11. 📁 PHASE6_CHARTS_COMPLETE.md → docs/reports/phase6/
12. 📁 BACKEND_IMPLEMENTATION_COMPLETE.md → docs/reports/backend/

### 迁移到 docs/analysis/ (3个)
13. 📁 PHASE4_MEMBER_SYSTEM_ANALYSIS.md
14. 📁 PHASE5_SPLIT_RULES_ANALYSIS.md
15. 📁 PHASE6_CHARTS_ANALYSIS.md

### 迁移到 docs/guides/ (5个)
16. 📁 PHASE3_INTEGRATION_GUIDE.md
17. 📁 PHASE3_README.md
18. 📁 BACKEND_RUST_IMPLEMENTATION.md
19. 📁 API_INTEGRATION_CHECKLIST.md
20. 📁 QUICK_START_UI_VALIDATION.md

### 迁移到 docs/archive/ (2个)
21. 📁 PHASE_FILES_CLEANUP_REPORT.md
22. 📁 BACKEND_FILES_CLEANUP_REPORT.md

---

## 🎯 迁移优势

1. **结构清晰**: 按文档类型和功能分类
2. **易于查找**: 开发、报告、分析、指南分离
3. **根目录简洁**: 只保留核心文档
4. **便于维护**: 后续文档有明确归属

---

## ✅ 执行步骤

1. 创建目录结构
2. 移动文件到对应目录
3. 创建 docs/README.md 索引
4. 验证迁移结果
