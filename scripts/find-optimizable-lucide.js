/**
 * 查找可以移除 Lucide 导入的 Vue 文件
 * 
 * 规则：
 * - 文件导入了 lucide-vue-next
 * - 图标仅在模板中使用（<LucideXxx />形式或需要转换的<Xxx />形式）
 * - 图标未在 script 中作为值使用
 */

const fs = require('fs');
const path = require('path');
const { glob } = require('glob');

// 查找所有 Vue 文件
const files = glob.sync('src/**/*.vue', { cwd: process.cwd() });

console.log(`总共找到 ${files.length} 个 Vue 文件`);
console.log('\n开始分析...\n');

const results = {
  canOptimize: [],
  mustKeep: [],
  noImport: [],
};

files.forEach(file => {
  const fullPath = path.join(process.cwd(), file);
  const content = fs.readFileSync(fullPath, 'utf-8');
  
  // 检查是否导入了 lucide-vue-next
  const importMatch = content.match(/import\s+{([^}]+)}\s+from\s+['"]lucide-vue-next['"]/);
  
  if (!importMatch) {
    results.noImport.push(file);
    return;
  }
  
  // 提取导入的图标名称
  const imports = importMatch[1]
    .split(',')
    .map(s => s.trim())
    .filter(s => s.length > 0);
  
  // 提取 script 部分
  const scriptMatch = content.match(/<script[^>]*>([\s\S]*?)<\/script>/);
  if (!scriptMatch) {
    results.canOptimize.push({ file, imports, reason: 'No script section' });
    return;
  }
  
  const scriptContent = scriptMatch[1];
  
  // 检查这些图标是否在 script 中作为值使用
  const usedAsValue = imports.some(iconName => {
    // 常见的作为值使用的模式：
    // 1. icon: IconName
    // 2. = IconName
    // 3. [IconName]
    // 4. (IconName)
    // 5. :icon="IconName"
    const patterns = [
      new RegExp(`:\\s*${iconName}\\b`, 'g'),           // icon: IconName
      new RegExp(`=\\s*${iconName}\\b`, 'g'),            // = IconName
      new RegExp(`\\[${iconName}\\]`, 'g'),              // [IconName]
      new RegExp(`\\(${iconName}\\)`, 'g'),              // (IconName)
      new RegExp(`:icon=["']?${iconName}["']?`, 'g'),    // :icon="IconName"
    ];
    
    return patterns.some(pattern => pattern.test(scriptContent));
  });
  
  if (usedAsValue) {
    results.mustKeep.push({
      file,
      imports,
      reason: 'Used as value in script',
    });
  } else {
    results.canOptimize.push({
      file,
      imports,
      reason: 'Only used in template',
    });
  }
});

// 输出结果
console.log('='.repeat(80));
console.log('✅ 可以优化的文件（仅在模板中使用）');
console.log('='.repeat(80));
results.canOptimize.forEach(({ file, imports }) => {
  console.log(`\n${file}`);
  console.log(`  导入: ${imports.join(', ')}`);
});

console.log('\n\n');
console.log('='.repeat(80));
console.log('❌ 必须保留的文件（在 script 中作为值使用）');
console.log('='.repeat(80));
results.mustKeep.forEach(({ file, imports, reason }) => {
  console.log(`\n${file}`);
  console.log(`  导入: ${imports.join(', ')}`);
  console.log(`  原因: ${reason}`);
});

console.log('\n\n');
console.log('='.repeat(80));
console.log('📊 统计');
console.log('='.repeat(80));
console.log(`总文件数: ${files.length}`);
console.log(`无导入: ${results.noImport.length}`);
console.log(`可优化: ${results.canOptimize.length} 🎯`);
console.log(`必须保留: ${results.mustKeep.length}`);
console.log(`\n预计可减少导入: ${results.canOptimize.length} 行`);

// 保存结果到文件
const reportPath = 'scripts/lucide-optimization-report.json';
fs.writeFileSync(
  reportPath,
  JSON.stringify(results, null, 2),
  'utf-8'
);

console.log(`\n详细报告已保存到: ${reportPath}`);
