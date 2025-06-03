<script lang="ts">
  import { createEventDispatcher } from 'svelte';

  const dispatch = createEventDispatcher();

  export let value: string = '';
  export let label: string = '选择日期';
  export let placeholder: string = 'YYYY-MM-DD';

  let showCalendar: boolean = false;
  let selectedDate: Date | null = null;

  function toggleCalendar() {
    showCalendar = !showCalendar;
  }

  function selectDate(date: Date) {
    selectedDate = date;
    value = date.toISOString().slice(0, 10); // Format YYYY-MM-DD
    dispatch('change', value);
    showCalendar = false;
  }

  // Basic calendar logic (placeholder)
  $: if (selectedDate) {
    // Logic to render calendar based on selectedDate
    // For now, just showing a placeholder
  }
</script>

<div class="relative w-full">
  <label for="date-picker-input" class="block text-sm font-medium text-gray-700 mb-1">{label}</label>
  <input
    id="date-picker-input"
    type="text"
    placeholder="{placeholder}"
    bind:value="{value}"
    on:focus="{toggleCalendar}"
    class="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
  />

  {#if showCalendar}
    <div
      class="absolute z-10 mt-1 bg-white border border-gray-300 rounded-md shadow-lg p-4"
      on:click:outside="{() => (showCalendar = false)}"
    >
      <h3 class="text-lg font-semibold mb-2">日历占位符</h3>
      <p class="text-sm text-gray-500">（此处将实现完整的日期选择逻辑）</p>
      <div class="grid grid-cols-7 gap-2 text-center text-sm">
        <div class="font-bold">日</div>
        <div class="font-bold">一</div>
        <div class="font-bold">二</div>
        <div class="font-bold">三</div>
        <div class="font-bold">四</div>
        <div class="font-bold">五</div>
        <div class="font-bold">六</div>
        <!-- Example days -->
        {#each Array(30) as _, i}
          <button
            class="p-2 rounded-full hover:bg-blue-100 {value === `2024-01-${i + 1 < 10 ? '0' : ''}${i + 1}` ? 'bg-blue-500 text-white' : ''}"
            on:click="{() => selectDate(new Date(`2024-01-${i + 1}`))}"
          >
            {i + 1}
          </button>
        {/each}
      </div>
      <button class="mt-4 w-full bg-blue-500 text-white py-2 rounded-md hover:bg-blue-600" on:click="{() => (showCalendar = false)}">关闭</button>
    </div>
  {/if}
</div>

<style lang="postcss">
  /* @tailwind base; */
  /* @tailwind components; */
  /* @tailwind utilities; */

  /* Custom styles for outside click detection */
  /* This would typically be handled by a Svelte action */
</style> 