<script lang="ts">
  import { createEventDispatcher } from 'svelte';

  const dispatch = createEventDispatcher();

  export let isOpen: boolean = false;
  export let position: 'left' | 'right' = 'right'; // 'left' or 'right'
  export let width: string = 'w-64'; // Tailwind CSS width class, e.g., w-64, w-1/3, w-full
  export let zIndex: number = 50; // Tailwind CSS z-index class, e.g., z-50

  function closeDrawer() {
    isOpen = false;
    dispatch('close');
  }

  function handleKeydown(event: KeyboardEvent) {
    if (event.key === 'Escape') {
      closeDrawer();
    }
  }

  // Add global keydown listener when drawer is open
  $: if (isOpen) {
    window.addEventListener('keydown', handleKeydown);
  } else {
    window.removeEventListener('keydown', handleKeydown);
  }
</script>

{#if isOpen}
  <div
    class="fixed inset-0 bg-black bg-opacity-50 transition-opacity duration-300 ease-in-out"
    class:opacity-100="{isOpen}"
    class:opacity-0="{!isOpen}"
    style="z-index: {zIndex - 1};"
    on:click="{closeDrawer}"
  ></div>

  <aside
    class="fixed inset-y-0 bg-white shadow-lg transform transition-transform duration-300 ease-in-out"
    class:translate-x-full="{position === 'right' && !isOpen}"
    class:-translate-x-full="{position === 'left' && !isOpen}"
    class:translate-x-0="{isOpen}"
    class:right-0="{position === 'right'}"
    class:left-0="{position === 'left'}"
    style="z-index: {zIndex};"
    class:{width}
  >
    <div class="p-4 flex justify-between items-center border-b">
      <h2 class="text-lg font-semibold">抽屉标题</h2>
      <button
        class="text-gray-500 hover:text-gray-700 focus:outline-none"
        on:click="{closeDrawer}"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-6 w-6"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M6 18L18 6M6 6l12 12"
          />
        </svg>
      </button>
    </div>
    <div class="p-4">
      <slot></slot>
    </div>
  </aside>
{/if}

<style lang="postcss">
  /* @tailwind base; */
  /* @tailwind components; */
  /* @tailwind utilities; */
</style> 