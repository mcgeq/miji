export function usePeriodPhase() {
  const periodStore = usePeriodStore();
  const { t } = useI18n();

  const currentPhase = computed(() => periodStore.periodStats);

  const currentPhaseLabel = computed(() => {
    const labels = {
      Menstrual: t('period.phases.menstrual'),
      Follicular: t('period.phases.follicular'),
      Ovulation: t('period.phases.ovulation'),
      Luteal: t('period.phases.luteal'),
    };
    return labels[currentPhase.value.currentPhase];
  });

  const daysUntilNext = computed(() => {
    const days = periodStore.periodStats.daysUntilNext;
    if (days === 0) return t('period.nextPeriod.todayStart');
    if (days === 1) return t('period.nextPeriod.tomorrowStart');
    if (days < 0) return t('period.nextPeriod.delayed');
    return `${days}${t('period.nextPeriod.daysLater')}`;
  });

  return { currentPhase, currentPhaseLabel, daysUntilNext };
}
