import { useThemeStore } from '@/stores/theme';

export default function SettingsPage() {
  const { theme, setTheme } = useThemeStore();

  return (
    <div className="p-4 space-y-4">
      <h1 className="text-xl font-bold">设置</h1>

      <div>
        <label className="font-medium" htmlFor="theme-select">
          主题
        </label>
        <select
          className="ml-2 border px-2 py-1 rounded"
          value={theme}
          onChange={(e) =>
            setTheme(e.target.value as 'light' | 'dark' | 'system')
          }
        >
          <option value="system">跟随系统</option>
          <option value="light">浅色</option>
          <option value="dark">深色</option>
        </select>
      </div>
    </div>
  );
}
