const fs = require('fs');
const path = require('path');

const prdDir = path.join(__dirname);

console.log("Scanning for duplicate PRD prototype folders...\n");

const items = fs.readdirSync(prdDir, { withFileTypes: true });
const groups = {};

// This regex exactly matches the grouping logic in prd-runtime.js
const regex = /(?:_[0-9]+|_refined_surge|_updated_surge|_with_fair_pay_badge|_with_audit|_break_mode|_refined|_active)$/i;

for (const item of items) {
  if (item.isDirectory()) {
    const dirPath = path.join(prdDir, item.name);
    const codeHtmlPath = path.join(dirPath, 'code.html');

    // We only care about prototype directories that have a code.html file
    if (fs.existsSync(codeHtmlPath)) {
      const stats = fs.statSync(codeHtmlPath);
      const mtime = stats.mtimeMs;

      // Extract the semantic base name
      const baseName = item.name.replace(regex, '');
      
      if (!groups[baseName]) {
        groups[baseName] = [];
      }
      
      groups[baseName].push({
        name: item.name,
        path: dirPath,
        mtime: mtime
      });
    }
  }
}

let deletedCount = 0;

for (const [baseName, folders] of Object.entries(groups)) {
  if (folders.length > 1) {
    // Sort by modified time descending (newest first). 
    // Fallback to reverse alphabetical so e.g., "_3" beats "_2" if times are identical.
    folders.sort((a, b) => {
      if (b.mtime !== a.mtime) {
        return b.mtime - a.mtime;
      }
      return b.name.localeCompare(a.name);
    });

    const keeper = folders[0];
    console.log(`[Group] ${baseName}`);
    console.log(`  Keeping: ${keeper.name}`);

    // Delete all older duplicates
    for (let i = 1; i < folders.length; i++) {
      const duplicate = folders[i];
      console.log(`  Deleting duplicate: ${duplicate.name}`);
      fs.rmSync(duplicate.path, { recursive: true, force: true });
      deletedCount++;
    }
    console.log(''); // Add a blank line between groups
  }
}

console.log(`Cleanup complete! Successfully deleted ${deletedCount} duplicate folders.`);
