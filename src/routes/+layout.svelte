<script lang="ts">
import '$lib/i18n/i18n';
import { getDb } from '@/lib/db';
import { onMount } from 'svelte';
import { Toaster } from 'svelte-sonner';
onMount(async () => {
  try {
    const db = await getDb();
    const tables = await db.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';",
    );
    console.log('📦 所有用户定义的表:', tables);
  } catch (error) {
    console.error('❌ 查询表失败:', error);
  }
});
</script>

<slot />
<Toaster richColors position="top-center" duration={3500} expand closeButton theme="system"/>
