<script lang="ts">
  export let messages: Array<{ id: string; sender: string; content: string; timestamp: string; isUser: boolean }> = [];
  export let scrollToBottom: boolean = true;

  import { onMount, afterUpdate } from 'svelte';

  let messageListElement: HTMLElement;

  function autoScroll() {
    if (messageListElement && scrollToBottom) {
      messageListElement.scrollTop = messageListElement.scrollHeight;
    }
  }

  onMount(() => {
    autoScroll();
  });

  afterUpdate(() => {
    autoScroll();
  });
</script>

<div
  bind:this="{messageListElement}"
  class="flex-1 overflow-y-auto p-4 space-y-4 bg-gray-50"
>
  {#each messages as message (message.id)}
    <div class="flex {message.isUser ? 'justify-end' : 'justify-start'}">
      <div
        class="max-w-xs px-4 py-2 rounded-lg shadow-md {message.isUser
          ? 'bg-blue-500 text-white'
          : 'bg-white text-gray-800'}"
      >
        <p class="font-semibold">{message.sender}</p>
        <p>{message.content}</p>
        <p class="text-xs {message.isUser ? 'text-blue-200' : 'text-gray-500'} mt-1">
          {message.timestamp}
        </p>
      </div>
    </div>
  {:else}
    <p class="text-center text-gray-500">还没有消息。</p>
  {/each}
</div>

<style lang="postcss">
  /* @tailwind base; */
  /* @tailwind components; */
  /* @tailwind utilities; */
</style> 