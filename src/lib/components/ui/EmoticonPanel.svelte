<script>
  import { createEventDispatcher, onMount } from 'svelte';
  import TabNavigation from './TabNavigation.svelte';
  import Input from './Input.svelte';
  
  export let isOpen = false;
  export let showRecent = true;
  export let showSearch = true;
  export let maxRecent = 24;
  
  const dispatch = createEventDispatcher();
  
  let searchQuery = '';
  let currentCategory = 'recent';
  let recentEmojis = [];
  
  // 表情分类数据
  const emojiCategories = {
    recent: {
      name: '最近',
      icon: '🕒',
      emojis: []
    },
    people: {
      name: '人物',
      icon: '😊',
      emojis: [
        '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃',
        '😉', '😊', '😇', '🥰', '😍', '🤩', '😘', '😗', '☺️', '😚',
        '😙', '😋', '😛', '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫',
        '🤔', '🤐', '🤨', '😐', '😑', '😶', '😏', '😒', '🙄', '😬',
        '🤥', '😔', '😪', '🤤', '😴', '😷', '🤒', '🤕', '🤢', '🤮',
        '🤧', '🥵', '🥶', '🥴', '😵', '🤯', '🤠', '🥳', '😎', '🤓'
      ]
    },
    nature: {
      name: '自然',
      icon: '🌸',
      emojis: [
        '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐨', '🐯',
        '🦁', '🐮', '🐷', '🐸', '🐵', '🐔', '🐧', '🐦', '🐤', '🐣',
        '🦆', '🦅', '🦉', '🦇', '🐺', '🐗', '🐴', '🦄', '🐝', '🐛',
        '🦋', '🐌', '🐞', '🐜', '🦟', '🦗', '🕷️', '🦂', '🐢', '🐍',
        '🌸', '🌺', '🌻', '🌷', '🌹', '🥀', '🌾', '🌿', '🍀', '🍃',
        '🌳', '🌲', '🌱', '🌴', '🌵', '🌶️', '🍄', '🌰', '🌎', '🌍'
      ]
    },
    food: {
      name: '食物',
      icon: '🍕',
      emojis: [
        '🍎', '🍐', '🍊', '🍋', '🍌', '🍉', '🍇', '🍓', '🍈', '🍒',
        '🍑', '🥭', '🍍', '🥥', '🥝', '🍅', '🍆', '🥑', '🥦', '🥒',
        '🥬', '🌶️', '🌽', '🥕', '🥔', '🍠', '🥐', '🍞', '🥖', '🥨',
        '🧀', '🥚', '🍳', '🥞', '🥓', '🥩', '🍗', '🍖', '🌭', '🍔',
        '🍟', '🍕', '🥪', '🌮', '🌯', '🥙', '🥘', '🍝', '🍜', '🍲',
        '🍛', '🍣', '🍱', '🥟', '🍤', '🍙', '🍚', '🍘', '🍥', '🥮'
      ]
    },
    activity: {
      name: '活动',
      icon: '⚽',
      emojis: [
        '⚽', '🏀', '🏈', '⚾', '🥎', '🎾', '🏐', '🏉', '🥏', '🎱',
        '🪀', '🏓', '🏸', '🏒', '🏑', '🥍', '🏏', '⛳', '🪁', '🏹',
        '🎣', '🤿', '🥊', '🥋', '🎽', '🛹', '🛷', '⛸️', '🥌', '🎿',
        '⛷️', '🏂', '🪂', '🏋️‍♀️', '🏋️‍♂️', '🤼‍♀️', '🤼‍♂️', '🤸‍♀️', '🤸‍♂️', '⛹️‍♀️',
        '⛹️‍♂️', '🤺', '🤾‍♀️', '🤾‍♂️', '🏌️‍♀️', '🏌️‍♂️', '🏇', '🧘‍♀️', '🧘‍♂️', '🏄‍♀️',
        '🏄‍♂️', '🏊‍♀️', '🏊‍♂️', '🤽‍♀️', '🤽‍♂️', '🚣‍♀️', '🚣‍♂️', '🧗‍♀️', '🧗‍♂️', '🚵‍♀️'
      ]
    },
    travel: {
      name: '旅行',
      icon: '🚗',
      emojis: [
        '🚗', '🚕', '🚙', '🚌', '🚎', '🏎️', '🚓', '🚑', '🚒', '🚐',
        '🛻', '🚚', '🚛', '🚜', '🏍️', '🛵', '🚲', '🛴', '🛹', '🚁',
        '✈️', '🛫', '🛬', '🪂', '💺', '🚀', '🛸', '🚉', '🚊', '🚝',
        '🚞', '🚋', '🚃', '🚂', '🚄', '🚅', '🚆', '🚇', '🚈', '🚉',
        '🚊', '🚝', '🚞', '🚋', '🚃', '🚂', '🚄', '🚅', '🚆', '⛵',
        '🛥️', '🚤', '⛴️', '🛳️', '🚢', '⚓', '⛽', '🚧', '🚥', '🚦'
      ]
    },
    objects: {
      name: '物品',
      icon: '📱',
      emojis: [
        '⌚', '📱', '📲', '💻', '⌨️', '🖥️', '🖨️', '🖱️', '🖲️', '🕹️',
        '🗜️', '💽', '💾', '💿', '📀', '📼', '📷', '📸', '📹', '🎥',
        '📽️', '🎞️', '📞', '☎️', '📟', '📠', '📺', '📻', '🎙️', '🎚️',
        '🎛️', '⏰', '🕰️', '⏱️', '⏲️', '⏰', '🕰️', '📡', '🔋', '🔌',
        '💡', '🔦', '🕯️', '🪔', '🧯', '🛢️', '💸', '💵', '💴', '💶',
        '💷', '💰', '💳', '💎', '⚖️', '🦯', '🧰', '🔧', '🔨', '⚒️'
      ]
    },
    symbols: {
      name: '符号',
      icon: '❤️',
      emojis: [
        '❤️', '🧡', '💛', '💚', '💙', '💜', '🤎', '🖤', '🤍', '💔',
        '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝', '💟', '☮️',
        '✝️', '☪️', '🕉️', '☸️', '✡️', '🔯', '🕎', '☯️', '☦️', '🛐',
        '⛎', '♈', '♉', '♊', '♋', '♌', '♍', '♎', '♏', '♐',
        '♑', '♒', '♓', '🆔', '⚛️', '🉑', '☢️', '☣️', '📴', '📳',
        '🈶', '🈚', '🈸', '🈺', '🈷️', '✴️', '🆚', '💮', '🉐', '㊙️'
      ]
    },
    flags: {
      name: '旗帜',
      icon: '🏳️',
      emojis: [
        '🏁', '🚩', '🎌', '🏴', '🏳️', '🏳️‍🌈', '🏳️‍⚧️', '🏴‍☠️', '🇦🇫', '🇦🇽',
        '🇦🇱', '🇩🇿', '🇦🇸', '🇦🇩', '🇦🇴', '🇦🇮', '🇦🇶', '🇦🇬', '🇦🇷', '🇦🇲',
        '🇦🇼', '🇦🇺', '🇦🇹', '🇦🇿', '🇧🇸', '🇧🇭', '🇧🇩', '🇧🇧', '🇧🇾', '🇧🇪',
        '🇧🇿', '🇧🇯', '🇧🇲', '🇧🇹', '🇧🇴', '🇧🇦', '🇧🇼', '🇧🇷', '🇮🇴', '🇻🇬',
        '🇧🇳', '🇧🇬', '🇧🇫', '🇧🇮', '🇰🇭', '🇨🇲', '🇨🇦', '🇮🇨', '🇨🇻', '🇧🇶',
        '🇰🇾', '🇨🇫', '🇹🇩', '🇨🇱', '🇨🇳', '🇨🇽', '🇨🇨', '🇨🇴', '🇰🇲', '🇨🇬'
      ]
    }
  };
  
  // 标签页配置
  $: tabs = Object.entries(emojiCategories).map(([key, category]) => ({
    id: key,
    label: category.name,
    icon: category.icon
  }));
  
  // 过滤后的表情
  $: filteredEmojis = searchQuery.trim() 
    ? Object.values(emojiCategories)
        .flatMap(cat => cat.emojis)
        .filter(emoji => {
          // 这里可以添加更复杂的搜索逻辑
          return true; // 简化处理，实际应该根据表情名称或标签搜索
        })
    : currentCategory === 'recent' 
      ? recentEmojis
      : emojiCategories[currentCategory]?.emojis || [];
  
  function handleEmojiClick(emoji) {
    // 添加到最近使用
    addToRecent(emoji);
    
    dispatch('select', { emoji });
  }
  
  function addToRecent(emoji) {
    // 移除已存在的
    recentEmojis = recentEmojis.filter(e => e !== emoji);
    // 添加到开头
    recentEmojis = [emoji, ...recentEmojis].slice(0, maxRecent);
    
    // 保存到本地存储
    if (typeof localStorage !== 'undefined') {
      localStorage.setItem('chat-recent-emojis', JSON.stringify(recentEmojis));
    }
  }
  
  function handleCategoryChange(event) {
    currentCategory = event.detail.activeTab;
  }
  
  function handleClose() {
    dispatch('close');
  }
  
  function handleSearchClear() {
    searchQuery = '';
  }
  
  onMount(() => {
    // 加载最近使用的表情
    if (typeof localStorage !== 'undefined') {
      const saved = localStorage.getItem('chat-recent-emojis');
      if (saved) {
        try {
          recentEmojis = JSON.parse(saved);
        } catch (e) {
          console.error('Failed to load recent emojis:', e);
        }
      }
    }
  });
</script>

{#if isOpen}
  <div class="emoticon-panel">
    <!-- 面板头部 -->
    <header class="panel-header">
      <h3 class="panel-title">选择表情</h3>
      <button class="close-btn" on:click={handleClose}>
        ✕
      </button>
    </header>
    
    <!-- 搜索栏 -->
    {#if showSearch}
      <div class="search-section">
        <Input
          placeholder="搜索表情..."
          bind:value={searchQuery}
          type="search"
          size="sm"
          on:clear={handleSearchClear}
        />
      </div>
    {/if}
    
    <!-- 分类标签 -->
    {#if !searchQuery}
      <div class="category-tabs">
        <TabNavigation
          {tabs}
          activeTab={currentCategory}
          variant="icons"
          size="sm"
          showIndicator={false}
          on:change={handleCategoryChange}
        />
      </div>
    {/if}
    
    <!-- 表情网格 -->
    <div class="emoji-grid-container">
      {#if filteredEmojis.length === 0}
        <div class="empty-state">
          {#if searchQuery}
            <div class="empty-icon">🔍</div>
            <div class="empty-text">没有找到相关表情</div>
          {:else if currentCategory === 'recent'}
            <div class="empty-icon">😊</div>
            <div class="empty-text">还没有最近使用的表情</div>
            <div class="empty-hint">点击表情即可使用</div>
          {:else}
            <div class="empty-icon">📦</div>
            <div class="empty-text">暂无表情</div>
          {/if}
        </div>
      {:else}
        <div class="emoji-grid">
          {#each filteredEmojis as emoji, index (emoji)}
            <button
              class="emoji-item"
              on:click={() => handleEmojiClick(emoji)}
              style="animation-delay: {index * 10}ms;"
            >
              <span class="emoji-char">{emoji}</span>
            </button>
          {/each}
        </div>
      {/if}
    </div>
    
    <!-- 最近使用提示 -->
    {#if !searchQuery && currentCategory !== 'recent' && showRecent}
      <div class="recent-hint">
        💡 最近使用的表情会保存在"最近"分类中
      </div>
    {/if}
  </div>
{/if}

<style>
  .emoticon-panel {
    background: white;
    border-radius: 16px;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.15);
    border: 1px solid #e5e7eb;
    width: 320px;
    max-height: 400px;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    animation: panelSlideIn 0.3s ease-out;
  }
  
  @keyframes panelSlideIn {
    from {
      opacity: 0;
      transform: translateY(10px) scale(0.95);
    }
    to {
      opacity: 1;
      transform: translateY(0) scale(1);
    }
  }
  
  /* 面板头部 */
  .panel-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 16px 20px 12px 20px;
    border-bottom: 1px solid #f3f4f6;
  }
  
  .panel-title {
    font-size: 16px;
    font-weight: 600;
    color: #111827;
    margin: 0;
  }
  
  .close-btn {
    background: none;
    border: none;
    font-size: 16px;
    color: #6b7280;
    cursor: pointer;
    padding: 4px;
    border-radius: 4px;
    transition: all 0.2s ease;
  }
  
  .close-btn:hover {
    color: #111827;
    background: #f3f4f6;
  }
  
  /* 搜索部分 */
  .search-section {
    padding: 12px 20px;
    border-bottom: 1px solid #f3f4f6;
  }
  
  /* 分类标签 */
  .category-tabs {
    padding: 12px 16px;
    border-bottom: 1px solid #f3f4f6;
    overflow-x: auto;
  }
  
  /* 表情网格容器 */
  .emoji-grid-container {
    flex: 1;
    overflow-y: auto;
    padding: 16px 20px;
    min-height: 200px;
  }
  
  .emoji-grid {
    display: grid;
    grid-template-columns: repeat(8, 1fr);
    gap: 8px;
  }
  
  .emoji-item {
    aspect-ratio: 1;
    background: none;
    border: none;
    border-radius: 8px;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.2s ease;
    opacity: 0;
    animation: emojiSlideIn 0.3s ease-out forwards;
  }
  
  .emoji-item:hover {
    background: #f3f4f6;
    transform: scale(1.2);
  }
  
  .emoji-item:active {
    transform: scale(1.1);
  }
  
  @keyframes emojiSlideIn {
    from {
      opacity: 0;
      transform: translateY(10px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }
  
  .emoji-char {
    font-size: 20px;
    line-height: 1;
    pointer-events: none;
  }
  
  /* 空状态 */
  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    text-align: center;
    padding: 40px 20px;
    height: 100%;
  }
  
  .empty-icon {
    font-size: 32px;
    margin-bottom: 12px;
    opacity: 0.5;
  }
  
  .empty-text {
    font-size: 14px;
    color: #6b7280;
    font-weight: 500;
    margin-bottom: 4px;
  }
  
  .empty-hint {
    font-size: 12px;
    color: #9ca3af;
  }
  
  /* 最近使用提示 */
  .recent-hint {
    padding: 12px 20px;
    background: #f8fafc;
    border-top: 1px solid #e5e7eb;
    font-size: 12px;
    color: #6b7280;
    text-align: center;
    line-height: 1.4;
  }
  
  /* 滚动条样式 */
  .emoji-grid-container::-webkit-scrollbar {
    width: 6px;
  }
  
  .emoji-grid-container::-webkit-scrollbar-track {
    background: #f1f5f9;
    border-radius: 3px;
  }
  
  .emoji-grid-container::-webkit-scrollbar-thumb {
    background: #cbd5e1;
    border-radius: 3px;
  }
  
  .emoji-grid-container::-webkit-scrollbar-thumb:hover {
    background: #94a3b8;
  }
  
  .category-tabs::-webkit-scrollbar {
    height: 4px;
  }
  
  .category-tabs::-webkit-scrollbar-track {
    background: #f1f5f9;
    border-radius: 2px;
  }
  
  .category-tabs::-webkit-scrollbar-thumb {
    background: #cbd5e1;
    border-radius: 2px;
  }
  
  /* 移动端适配 */
  @media (max-width: 640px) {
    .emoticon-panel {
      width: 280px;
      max-height: 350px;
    }
    
    .panel-header {
      padding: 12px 16px 8px 16px;
    }
    
    .panel-title {
      font-size: 14px;
    }
    
    .search-section {
      padding: 8px 16px;
    }
    
    .category-tabs {
      padding: 8px 12px;
    }
    
    .emoji-grid-container {
      padding: 12px 16px;
      min-height: 160px;
    }
    
    .emoji-grid {
      grid-template-columns: repeat(7, 1fr);
      gap: 6px;
    }
    
    .emoji-char {
      font-size: 18px;
    }
    
    .empty-state {
      padding: 30px 16px;
    }
    
    .empty-icon {
      font-size: 28px;
    }
    
    .recent-hint {
      padding: 8px 16px;
      font-size: 11px;
    }
  }
  
  /* 高分辨率屏幕优化 */
  @media (min-resolution: 2dppx) {
    .emoji-char {
      image-rendering: -webkit-optimize-contrast;
      image-rendering: crisp-edges;
    }
  }
</style> 