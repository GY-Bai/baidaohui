import { c as create_ssr_component, e as each, b as escape, d as add_attribute, f as createEventDispatcher, v as validate_component } from "../../chunks/ssr.js";
const app = "";
function getMenuItems(role) {
  const baseItems = [
    {
      name: "私信",
      href: "/chat",
      icon: "💬"
    },
    {
      name: "算命",
      href: "/fortune",
      icon: "🔮"
    },
    {
      name: "带货",
      href: "/shop",
      icon: "🛍️"
    },
    {
      name: "个人",
      href: "/profile",
      icon: "👤"
    }
  ];
  if (role === "master" || role === "firstmate") {
    return [
      ...baseItems,
      {
        name: "邀请链接",
        href: "/invite",
        icon: "🔗"
      },
      {
        name: "算命开关",
        href: "/fortune/settings",
        icon: "⚙️"
      }
    ];
  }
  return baseItems;
}
const NavBar = create_ssr_component(($$result, $$props, $$bindings, slots) => {
  let menuItems;
  let { userRole: userRole2 = "fan" } = $$props;
  let { userName = "" } = $$props;
  if ($$props.userRole === void 0 && $$bindings.userRole && userRole2 !== void 0)
    $$bindings.userRole(userRole2);
  if ($$props.userName === void 0 && $$bindings.userName && userName !== void 0)
    $$bindings.userName(userName);
  menuItems = getMenuItems(userRole2);
  return `<nav class="bg-white shadow-sm border-b border-gray-200"><div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8"><div class="flex justify-between h-16"> <div class="flex"><div class="flex-shrink-0 flex items-center" data-svelte-h="svelte-1iequqv"><div class="h-8 w-8 rounded-full bg-gradient-to-r from-blue-600 to-purple-600 flex items-center justify-center"><span class="text-sm font-bold text-white">百</span></div> <span class="ml-2 text-xl font-semibold text-gray-900">百刀会</span></div>  <div class="hidden sm:ml-6 sm:flex sm:space-x-8">${each(menuItems, (item) => {
    return `<a${add_attribute("href", item.href, 0)} class="inline-flex items-center px-1 pt-1 text-sm font-medium text-gray-500 hover:text-gray-700 hover:border-gray-300 transition-colors duration-200"><span class="mr-1">${escape(item.icon)}</span> ${escape(item.name)} </a>`;
  })}</div></div>  <div class="hidden sm:ml-6 sm:flex sm:items-center"><div class="relative"><button type="button" class="bg-white rounded-full flex text-sm focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"><span class="sr-only" data-svelte-h="svelte-1pelpmi">打开用户菜单</span> <div class="h-8 w-8 rounded-full bg-gray-300 flex items-center justify-center"><span class="text-sm font-medium text-gray-700">${escape(userName ? userName.charAt(0).toUpperCase() : "用")}</span></div></button> ${``}</div></div>  <div class="sm:hidden flex items-center"><button type="button" class="inline-flex items-center justify-center p-2 rounded-md text-gray-400 hover:text-gray-500 hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-blue-500"><span class="sr-only" data-svelte-h="svelte-wobng2">打开主菜单</span> ${`<svg class="block h-6 w-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"></path></svg>`}</button></div></div></div>  ${``}</nav>  ${``}`;
});
const nicknameRegex = /^[\u4e00-\u9fa5a-zA-Z\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]+$/u;
function getAuthToken() {
  return localStorage.getItem("supabase.auth.token") || "";
}
const NicknameDialog = create_ssr_component(($$result, $$props, $$bindings, slots) => {
  createEventDispatcher();
  let { isOpen = false } = $$props;
  let { currentNickname = "" } = $$props;
  let nickname = currentNickname;
  let isValidating = false;
  let isSubmitting = false;
  let error = "";
  let validationMessage = "";
  function validateNickname() {
    error = "";
    validationMessage = "";
    if (!nickname.trim()) {
      error = "昵称不能为空";
      return;
    }
    if (nickname.length < 2) {
      error = "昵称至少需要2个字符";
      return;
    }
    if (nickname.length > 20) {
      error = "昵称不能超过20个字符";
      return;
    }
    if (!nicknameRegex.test(nickname)) {
      error = "昵称只能包含中文、英文字母和emoji";
      return;
    }
    if (nickname !== currentNickname) {
      checkNicknameAvailability();
    }
  }
  async function checkNicknameAvailability() {
    if (isValidating)
      return;
    try {
      isValidating = true;
      const response = await fetch("/api/profile/validate_nickname", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${getAuthToken()}`
        },
        body: JSON.stringify({ nickname })
      });
      const data = await response.json();
      if (!response.ok) {
        if (response.status === 409) {
          error = "昵称已被占用，请选择其他昵称";
        } else {
          error = data.message || "验证失败，请重试";
        }
      } else {
        validationMessage = "昵称可用";
      }
    } catch (err) {
      console.error("昵称验证失败:", err);
      error = "网络错误，请重试";
    } finally {
      isValidating = false;
    }
  }
  if ($$props.isOpen === void 0 && $$bindings.isOpen && isOpen !== void 0)
    $$bindings.isOpen(isOpen);
  if ($$props.currentNickname === void 0 && $$bindings.currentNickname && currentNickname !== void 0)
    $$bindings.currentNickname(currentNickname);
  {
    if (nickname) {
      validateNickname();
    }
  }
  return `${isOpen ? ` <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50"><div class="bg-white rounded-lg shadow-xl max-w-md w-full"> <div class="px-6 py-4 border-b border-gray-200"><h3 class="text-lg font-semibold text-gray-900">${escape(currentNickname ? "修改昵称" : "设置昵称")}</h3> <p class="mt-1 text-sm text-gray-600">${escape(currentNickname ? "您可以修改您的昵称" : "请设置您的昵称以继续使用")}</p></div>  <div class="px-6 py-4"><div class="mb-4"><label for="nickname" class="block text-sm font-medium text-gray-700 mb-2" data-svelte-h="svelte-1jvocfx">昵称</label> <input id="nickname" type="text" placeholder="请输入昵称（中文、英文、emoji）" class="${"block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 " + escape(error ? "border-red-300" : "", true)}" maxlength="20"${add_attribute("value", nickname, 0)}>  <div class="mt-2 min-h-[1.25rem]">${isValidating ? `<div class="flex items-center text-sm text-gray-500" data-svelte-h="svelte-1964u8b"><svg class="animate-spin -ml-1 mr-2 h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
                验证中...</div>` : `${error ? `<p class="text-sm text-red-600">${escape(error)}</p>` : `${validationMessage ? `<p class="text-sm text-green-600">${escape(validationMessage)}</p>` : ``}`}`}</div></div>  <div class="bg-blue-50 rounded-md p-3 mb-4" data-svelte-h="svelte-1szhm8"><h4 class="text-sm font-medium text-blue-900 mb-1">昵称规则</h4> <ul class="text-sm text-blue-700 space-y-1"><li>• 长度：2-20个字符</li> <li>• 格式：仅支持中文、英文字母和emoji</li> <li>• 唯一性：不能与其他用户重复</li></ul></div></div>  <div class="px-6 py-4 border-t border-gray-200 flex justify-end space-x-3">${currentNickname ? `<button type="button" class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2" data-svelte-h="svelte-1szimb6">取消</button>` : ``} <button type="button" ${!!error || isValidating || isSubmitting || !nickname.trim() ? "disabled" : ""} class="px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed">${`${escape(currentNickname ? "更新昵称" : "设置昵称")}`}</button></div></div></div>` : ``}`;
});
let userRole = "fan";
const Layout = create_ssr_component(($$result, $$props, $$bindings, slots) => {
  let userName = "";
  let showNicknameDialog = false;
  let $$settled;
  let $$rendered;
  let previous_head = $$result.head;
  do {
    $$settled = true;
    $$result.head = previous_head;
    $$rendered = `${$$result.head += `<!-- HEAD_svelte-tcxiz7_START -->${$$result.title = `<title>百刀会 - Fan</title>`, ""}<!-- HEAD_svelte-tcxiz7_END -->`, ""} <div class="min-h-screen bg-gray-50">${validate_component(NavBar, "NavBar").$$render($$result, { userRole, userName }, {}, {})} <main>${slots.default ? slots.default({}) : ``}</main>  ${validate_component(NicknameDialog, "NicknameDialog").$$render(
      $$result,
      {
        currentNickname: userName,
        isOpen: showNicknameDialog
      },
      {
        isOpen: ($$value) => {
          showNicknameDialog = $$value;
          $$settled = false;
        }
      },
      {}
    )}</div>`;
  } while (!$$settled);
  return $$rendered;
});
export {
  Layout as default
};
