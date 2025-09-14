import { ref } from 'vue';

export function useSuccessToast() {
  const showSuccessMessage = ref(false);
  const successMessage = ref('');

  function show(message: string) {
    successMessage.value = message;
    showSuccessMessage.value = true;
    setTimeout(() => {
      showSuccessMessage.value = false;
    }, 3000);
  }

  function hide() {
    showSuccessMessage.value = false;
  }

  return { showSuccessMessage, successMessage, show, hide };
}
