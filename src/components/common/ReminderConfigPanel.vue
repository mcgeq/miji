<script setup lang="ts">
  import { Bell, Calendar, Clock, MapPin, Settings as SettingsIcon, Zap } from 'lucide-vue-next';
  import DateTimePicker from '@/components/common/DateTimePicker.vue';
  import RepeatPeriodSelector from '@/components/common/RepeatPeriodSelector.vue';
  import { Checkbox, FormRow, Select } from '@/components/ui';
  import type {
    AdvanceUnit,
    BaseReminderConfig,
    ReminderFrequency,
    SmartReminderConfig,
  } from '@/schema/notification/baseReminder';
  import {
    calculateNextReminderTime,
    createDefaultSmartConfig,
    DEFAULT_REMINDER_CONFIG,
    validateReminderConfig,
  } from '@/schema/notification/baseReminder';

  interface Props {
    modelValue: BaseReminderConfig;
    showAdvanced?: boolean;
    showSmartConfig?: boolean;
    allowedMethods?: ('desktop' | 'mobile' | 'email' | 'sms')[];
    compact?: boolean;
  }

  const props = withDefaults(defineProps<Props>(), {
    showAdvanced: true,
    showSmartConfig: true,
    allowedMethods: () => ['desktop', 'mobile', 'email', 'sms'],
    compact: false,
  });

  const emit = defineEmits<{
    'update:modelValue': [value: BaseReminderConfig];
    validate: [isValid: boolean];
  }>();

  const { t } = useI18n();

  const localConfig = ref<BaseReminderConfig>({
    ...DEFAULT_REMINDER_CONFIG,
    ...props.modelValue,
  });

  const advanceUnitOptions = computed(() => [
    { value: 'minutes', label: t('units.minutes') },
    { value: 'hours', label: t('units.hours') },
    { value: 'days', label: t('units.days') },
    { value: 'weeks', label: t('units.weeks') },
  ]);

  const frequencyOptions = computed(() => [
    { value: 'once', label: t('common.frequency.once') },
    { value: '15m', label: t('common.frequency.q15m') },
    { value: '1h', label: t('common.frequency.hourly') },
    { value: '1d', label: t('common.frequency.daily') },
    { value: 'daily', label: t('common.frequency.daily') },
    { value: 'weekly', label: t('common.frequency.weekly') },
    { value: 'custom', label: t('common.frequency.custom') },
  ]);

  const availableMethods = computed(() => {
    const allMethods = [
      { key: 'desktop', label: t('notification.methods.desktop'), icon: '💻' },
      { key: 'mobile', label: t('notification.methods.mobile'), icon: '📱' },
      { key: 'email', label: t('notification.methods.email'), icon: '✉️' },
      { key: 'sms', label: t('notification.methods.sms'), icon: '💬' },
    ];
    return allMethods.filter(m => props.allowedMethods.includes(m.key as any));
  });

  const nextReminderTime = computed(() => {
    return calculateNextReminderTime(localConfig.value);
  });

  const validationResult = computed(() => {
    return validateReminderConfig(localConfig.value);
  });

  const hasSmartFeatures = computed(() => {
    const smart = localConfig.value.smartConfig;
    return smart?.enabled && (smart.locationBased || smart.weatherDependent || smart.priorityBoost);
  });

  function updateConfig(updates: Partial<BaseReminderConfig>) {
    localConfig.value = {
      ...localConfig.value,
      ...updates,
    };
    emitUpdate();
  }

  function updateReminderMethods(
    key: keyof typeof localConfig.value.reminderMethods,
    value: boolean,
  ) {
    localConfig.value = {
      ...localConfig.value,
      reminderMethods: {
        ...localConfig.value.reminderMethods,
        [key]: value,
      },
    };
    emitUpdate();
  }

  function updateSmartConfig(updates: Partial<SmartReminderConfig>) {
    localConfig.value = {
      ...localConfig.value,
      smartConfig: {
        ...(localConfig.value.smartConfig || createDefaultSmartConfig()),
        ...updates,
      },
    };
    emitUpdate();
  }

  function emitUpdate() {
    emit('update:modelValue', localConfig.value);
    emit('validate', validationResult.value.isValid);
  }

  watch(
    () => props.modelValue,
    newVal => {
      localConfig.value = {
        ...DEFAULT_REMINDER_CONFIG,
        ...newVal,
      };
    },
    { deep: true },
  );

  watch(validationResult, result => {
    emit('validate', result.isValid);
  });
</script>

<template>
  <div class="reminder-config-panel" :class="{ compact }">
    <FormRow :label="t('notification.enableReminder')" :compact="compact">
      <div class="flex items-center gap-3">
        <label class="relative inline-flex items-center cursor-pointer">
          <input
            :checked="localConfig.enabled"
            type="checkbox"
            class="sr-only peer"
            @change="updateConfig({ enabled: !localConfig.enabled })"
          />
          <div
            class="w-11 h-6 bg-gray-200 dark:bg-gray-700 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 dark:peer-focus:ring-blue-800 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-0.5 after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600 dark:peer-checked:bg-blue-500"
          />
        </label>
        <span
          v-if="nextReminderTime"
          class="text-xs text-gray-500 dark:text-gray-400 flex items-center gap-1"
        >
          <Clock :size="14" />
          {{ t('notification.nextReminder') }}: {{ nextReminderTime.toLocaleString() }}
        </span>
      </div>
    </FormRow>

    <div v-if="localConfig.enabled" class="space-y-4 mt-4">
      <FormRow :label="t('notification.advanceTime')" required :compact="compact">
        <div class="flex gap-2">
          <input
            :value="localConfig.advanceValue"
            type="number"
            min="1"
            max="999"
            class="w-24 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-center bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            @input="updateConfig({ advanceValue: Number(($event.target as HTMLInputElement).value) })"
          />
          <Select
            :model-value="localConfig.advanceUnit"
            :options="advanceUnitOptions"
            class="flex-1"
            @update:model-value="updateConfig({ advanceUnit: $event as AdvanceUnit })"
          />
        </div>
      </FormRow>

      <FormRow :label="t('date.reminderDate')" required :compact="compact">
        <DateTimePicker
          :model-value="new Date(localConfig.remindDate)"
          @update:model-value="$event && updateConfig({ remindDate: $event.toISOString() })"
        />
      </FormRow>

      <FormRow :label="t('date.dueDate')" required :compact="compact">
        <DateTimePicker
          :model-value="new Date(localConfig.dueAt)"
          @update:model-value="$event && updateConfig({ dueAt: $event.toISOString() })"
        />
      </FormRow>

      <FormRow :label="t('date.repeat.frequency')" :compact="compact">
        <RepeatPeriodSelector
          :model-value="localConfig.repeatPeriod"
          label=""
          error-message=""
          help-text=""
          @update:model-value="updateConfig({ repeatPeriod: $event })"
        />
      </FormRow>

      <FormRow :label="t('notification.reminderFrequency')" :compact="compact">
        <Select
          :model-value="localConfig.reminderFrequency"
          :options="frequencyOptions"
          @update:model-value="updateConfig({ reminderFrequency: $event as ReminderFrequency })"
        />
      </FormRow>

      <FormRow :label="t('notification.reminderMethods')" required :compact="compact">
        <div class="flex flex-wrap gap-3">
          <label
            v-for="method in availableMethods"
            :key="method.key"
            class="flex items-center gap-2 px-3 py-2 border rounded-lg cursor-pointer transition-colors"
            :class="localConfig.reminderMethods[method.key as keyof typeof localConfig.reminderMethods] ? 'bg-blue-50 dark:bg-blue-900/20 border-blue-600 dark:border-blue-400' : 'border-gray-300 dark:border-gray-600 hover:border-blue-500 dark:hover:border-blue-400 bg-white dark:bg-gray-800'"
          >
            <input
              type="checkbox"
              :checked="localConfig.reminderMethods[method.key as keyof typeof localConfig.reminderMethods]"
              class="w-4 h-4 text-blue-600 border-gray-300 dark:border-gray-600 rounded focus:ring-blue-500 dark:focus:ring-blue-400"
              @change="updateReminderMethods(method.key as keyof typeof localConfig.reminderMethods, !localConfig.reminderMethods[method.key as keyof typeof localConfig.reminderMethods])"
            />
            <span class="text-sm"
              >{{ method.icon }}
              {{ method.label }}</span
            >
          </label>
        </div>
      </FormRow>

      <div
        v-if="validationResult.errors.length > 0"
        class="p-3 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg"
      >
        <div class="text-sm text-red-600 dark:text-red-400">
          <div v-for="(error, index) in validationResult.errors" :key="index">• {{ error }}</div>
        </div>
      </div>

      <details v-if="showAdvanced || showSmartConfig" class="mt-4">
        <summary
          class="cursor-pointer text-sm font-medium text-gray-700 dark:text-gray-300 flex items-center gap-2 hover:text-blue-600 dark:hover:text-blue-400"
        >
          <SettingsIcon :size="16" />
          {{ t('notification.advancedSettings') }}
        </summary>

        <div class="mt-4 space-y-4 pl-4 border-l-2 border-gray-200 dark:border-gray-700">
          <div v-if="showAdvanced">
            <h4
              class="text-sm font-semibold text-gray-900 dark:text-white mb-3 flex items-center gap-2"
            >
              <Bell :size="16" />
              {{ t('notification.advancedReminder') }}
            </h4>

            <div class="space-y-3">
              <FormRow :label="t('notification.snoozeUntil')" :compact="true">
                <DateTimePicker
                  :model-value="localConfig.snoozeUntil ? new Date(localConfig.snoozeUntil) : null"
                  :placeholder="t('notification.noSnooze')"
                  @update:model-value="updateConfig({ snoozeUntil: $event ? $event.toISOString() : undefined })"
                />
              </FormRow>

              <FormRow :label="t('notification.timezone')" :compact="true">
                <input
                  :value="localConfig.timezone"
                  type="text"
                  :placeholder="Intl.DateTimeFormat().resolvedOptions().timeZone"
                  class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
                  @input="updateConfig({ timezone: ($event.target as HTMLInputElement).value })"
                />
              </FormRow>
            </div>
          </div>

          <div v-if="showSmartConfig" class="mt-6">
            <h4
              class="text-sm font-semibold text-gray-900 dark:text-white mb-3 flex items-center gap-2"
            >
              <Zap :size="16" class="text-yellow-500" />
              {{ t('notification.smartReminder') }}
            </h4>

            <div class="space-y-3">
              <Checkbox
                :model-value="localConfig.smartConfig?.enabled || false"
                :label="t('notification.enableSmartReminder')"
                @update:model-value="updateSmartConfig({ enabled: Boolean($event) })"
              />

              <div
                v-if="localConfig.smartConfig?.enabled"
                class="space-y-3 pl-4 border-l-2 border-yellow-500 dark:border-yellow-400"
              >
                <div class="flex items-center gap-3">
                  <Checkbox
                    :model-value="localConfig.smartConfig?.locationBased || false"
                    :label="t('notification.locationBased')"
                    @update:model-value="updateSmartConfig({ locationBased: Boolean($event) })"
                  />
                  <MapPin :size="16" class="text-gray-400" />
                </div>

                <div class="flex items-center gap-3">
                  <Checkbox
                    :model-value="localConfig.smartConfig?.weatherDependent || false"
                    :label="t('notification.weatherDependent')"
                    @update:model-value="updateSmartConfig({ weatherDependent: Boolean($event) })"
                  />
                  <span class="text-base">🌤️</span>
                </div>

                <div class="flex items-center gap-3">
                  <Checkbox
                    :model-value="localConfig.smartConfig?.priorityBoost || false"
                    :label="t('notification.priorityBoost')"
                    @update:model-value="updateSmartConfig({ priorityBoost: Boolean($event) })"
                  />
                  <span class="text-base">⚡</span>
                </div>

                <div class="flex items-center gap-3">
                  <Checkbox
                    :model-value="localConfig.smartConfig?.calendarAware || false"
                    :label="t('notification.calendarAware')"
                    @update:model-value="updateSmartConfig({ calendarAware: Boolean($event) })"
                  />
                  <Calendar :size="16" class="text-gray-400" />
                </div>
              </div>
            </div>
          </div>

          <div
            v-if="hasSmartFeatures"
            class="mt-4 p-3 bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg"
          >
            <div class="text-sm text-blue-600 dark:text-blue-400 flex items-center gap-2">
              <Zap :size="14" />
              <span>{{ t('notification.smartFeaturesActive') }}</span>
            </div>
          </div>
        </div>
      </details>
    </div>
  </div>
</template>

<style scoped>
  .reminder-config-panel.compact {
    font-size: 0.875rem;
  }

  details > summary {
    list-style: none;
  }

  details > summary::-webkit-details-marker {
    display: none;
  }

  details[open] > summary::before {
    content: "▼ ";
  }

  details:not([open]) > summary::before {
    content: "▶ ";
  }
</style>
