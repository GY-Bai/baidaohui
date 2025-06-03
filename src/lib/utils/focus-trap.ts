/**
 * 焦点陷阱工具 - 用于模态框等组件的无障碍优化
 * 确保Tab键导航被限制在指定元素内
 */

const FOCUSABLE_SELECTORS = [
  'button:not([disabled])',
  'input:not([disabled])',
  'select:not([disabled])',
  'textarea:not([disabled])',
  'a[href]',
  '[tabindex]:not([tabindex="-1"])',
  '[contenteditable="true"]'
].join(', ');

export function trapFocus(node: HTMLElement): { destroy: () => void } {
  let isActive = true;
  let previouslyFocused: HTMLElement | null = null;

  // 保存当前焦点元素
  previouslyFocused = document.activeElement as HTMLElement;

  // 获取所有可聚焦元素
  function getFocusableElements(): HTMLElement[] {
    return Array.from(node.querySelectorAll(FOCUSABLE_SELECTORS)) as HTMLElement[];
  }

  // 设置初始焦点
  function setInitialFocus() {
    const focusableElements = getFocusableElements();
    if (focusableElements.length > 0) {
      // 优先聚焦第一个非关闭按钮的元素
      const firstNonCloseButton = focusableElements.find(
        el => !el.getAttribute('aria-label')?.includes('关闭')
      );
      (firstNonCloseButton || focusableElements[0]).focus();
    }
  }

  // 处理Tab键导航
  function handleKeyDown(event: KeyboardEvent) {
    if (!isActive || event.key !== 'Tab') return;

    const focusableElements = getFocusableElements();
    if (focusableElements.length === 0) {
      event.preventDefault();
      return;
    }

    const firstElement = focusableElements[0];
    const lastElement = focusableElements[focusableElements.length - 1];
    const currentFocused = document.activeElement as HTMLElement;

    // Shift + Tab (向前)
    if (event.shiftKey) {
      if (currentFocused === firstElement || !focusableElements.includes(currentFocused)) {
        event.preventDefault();
        lastElement.focus();
      }
    } 
    // Tab (向后)
    else {
      if (currentFocused === lastElement || !focusableElements.includes(currentFocused)) {
        event.preventDefault();
        firstElement.focus();
      }
    }
  }

  // 处理鼠标点击
  function handleMouseDown(event: MouseEvent) {
    if (!isActive) return;
    
    const target = event.target as HTMLElement;
    const focusableElements = getFocusableElements();
    
    // 如果点击的不是可聚焦元素，阻止默认行为
    if (!focusableElements.includes(target) && !target.closest('[role="dialog"]')) {
      event.preventDefault();
    }
  }

  // 监听事件
  document.addEventListener('keydown', handleKeyDown);
  document.addEventListener('mousedown', handleMouseDown);

  // 设置初始焦点
  setTimeout(setInitialFocus, 10);

  return {
    destroy() {
      isActive = false;
      
      // 移除事件监听器
      document.removeEventListener('keydown', handleKeyDown);
      document.removeEventListener('mousedown', handleMouseDown);
      
      // 恢复之前的焦点
      if (previouslyFocused && document.contains(previouslyFocused)) {
        previouslyFocused.focus();
      }
    }
  };
}

/**
 * 自动聚焦指令 - 用于自动聚焦到指定元素
 */
export function autoFocus(node: HTMLElement): { destroy: () => void } {
  // 延迟聚焦以确保元素已渲染
  const timeoutId = setTimeout(() => {
    if (document.contains(node)) {
      node.focus();
    }
  }, 10);

  return {
    destroy() {
      clearTimeout(timeoutId);
    }
  };
}

/**
 * 可聚焦元素管理器
 */
export class FocusManager {
  private stack: HTMLElement[] = [];

  /**
   * 推入新的焦点上下文
   */
  push(element: HTMLElement) {
    // 保存当前焦点
    const current = document.activeElement as HTMLElement;
    if (current && current !== document.body) {
      this.stack.push(current);
    }
    
    // 聚焦到新元素
    if (element && document.contains(element)) {
      element.focus();
    }
  }

  /**
   * 弹出当前焦点上下文，恢复到之前的焦点
   */
  pop(): HTMLElement | null {
    const previous = this.stack.pop();
    if (previous && document.contains(previous)) {
      previous.focus();
      return previous;
    }
    return null;
  }

  /**
   * 清空焦点栈
   */
  clear() {
    this.stack = [];
  }

  /**
   * 获取栈的大小
   */
  get size() {
    return this.stack.length;
  }
}

// 导出全局焦点管理器实例
export const focusManager = new FocusManager();

/**
 * 点击外部检测
 */
export function clickOutside(node: HTMLElement, callback: () => void) {
  function handleClick(event: MouseEvent) {
    if (!node.contains(event.target as Node)) {
      callback();
    }
  }

  document.addEventListener('click', handleClick, true);

  return {
    destroy() {
      document.removeEventListener('click', handleClick, true);
    }
  };
}

/**
 * Escape 键处理
 */
export function escapeKey(node: HTMLElement, callback: () => void) {
  function handleKeydown(event: KeyboardEvent) {
    if (event.key === 'Escape') {
      callback();
    }
  }

  node.addEventListener('keydown', handleKeydown);

  return {
    destroy() {
      node.removeEventListener('keydown', handleKeydown);
    }
  };
} 