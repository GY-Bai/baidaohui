import { c as create_ssr_component, d as add_attribute, e as escape } from "../../chunks/ssr.js";
import { createClient } from "@supabase/supabase-js";
const supabaseUrl = {}.VITE_SUPABASE_URL || "https://pvjowkjksutkhpsomwvv.supabase.co";
const supabaseAnonKey = {}.VITE_SUPABASE_ANON_KEY || "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB2am93a2prc3V0a2hwc29td3Z2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4NzYxMzEsImV4cCI6MjA2MzQ1MjEzMX0.m98BRjqAnpjVpyDxUC-9LRrU4B3SRXYdHMO3Dez-qyc";
const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true
  }
});
function redirectToRolePage(user) {
  const role = user.user_metadata?.role || user.app_metadata?.role || "fan";
  const roleSubdomains = {
    fan: "fan.baiduohui.com",
    member: "member.baiduohui.com",
    master: "master.baiduohui.com",
    firstmate: "firstmate.baiduohui.com"
  };
  const targetDomain = roleSubdomains[role] || "fan.baiduohui.com";
  window.location.assign(`https://${targetDomain}`);
}
const _page_svelte_svelte_type_style_lang = "";
const css = {
  code: "html, body{margin:0;padding:0;height:100%;background:transparent;overflow:hidden}.starfield.svelte-14g86y1.svelte-14g86y1{position:fixed;top:0;left:0;width:100vw;height:100vh;z-index:-1;background:black}.container.svelte-14g86y1.svelte-14g86y1{display:flex;min-height:100vh;align-items:center;justify-content:center;padding:1rem;background:transparent}.login-container.svelte-14g86y1.svelte-14g86y1{background:rgba(255, 255, 255, 0.85);backdrop-filter:blur(10px);border:1px solid rgba(255, 255, 255, 0.15);border-radius:20px;box-shadow:0 20px 40px rgba(0, 0, 0, 0.2), 0 0 60px rgba(135, 206, 235, 0.1);padding:2.5rem;width:100%;max-width:400px;text-align:center;z-index:10;animation:svelte-14g86y1-slideUp 0.6s cubic-bezier(0.25, 0.46, 0.45, 0.94)}@keyframes svelte-14g86y1-slideUp{from{opacity:0;transform:translateY(30px)}to{opacity:1;transform:translateY(0)}}.logo.svelte-14g86y1.svelte-14g86y1{width:80px;height:80px;background:linear-gradient(135deg, #667eea, #764ba2);border-radius:50%;margin:0 auto 2rem;display:flex;align-items:center;justify-content:center;box-shadow:0 0 20px rgba(102, 126, 234, 0.5);overflow:hidden;position:relative}.logo-img.svelte-14g86y1.svelte-14g86y1{width:100%;height:100%;object-fit:cover;border-radius:50%}.logo-fallback.svelte-14g86y1.svelte-14g86y1{color:white;font-size:2rem;font-weight:bold;display:none}.title.svelte-14g86y1.svelte-14g86y1{font-size:1.75rem;font-weight:bold;color:#333;margin-bottom:0.5rem}.subtitle.svelte-14g86y1.svelte-14g86y1{font-size:1rem;color:#666;margin-bottom:2.5rem}.google-btn.svelte-14g86y1.svelte-14g86y1{width:100%;padding:1rem;background:#4285f4;color:white;border:none;border-radius:12px;font-size:1rem;font-weight:500;cursor:pointer;display:flex;align-items:center;justify-content:center;gap:0.75rem;transition:all 0.2s;position:relative}.google-btn.svelte-14g86y1.svelte-14g86y1:hover{background:#3367d6;transform:translateY(-1px)}.google-btn.svelte-14g86y1.svelte-14g86y1:disabled{opacity:0.5;cursor:not-allowed;transform:none}.google-icon.svelte-14g86y1.svelte-14g86y1{width:20px;height:20px;background:white;border-radius:50%;display:flex;align-items:center;justify-content:center}.footer.svelte-14g86y1.svelte-14g86y1{margin-top:2rem;font-size:0.75rem;color:#aaa;line-height:1.5}.footer.svelte-14g86y1 a.svelte-14g86y1{color:#4285f4;text-decoration:none}.footer.svelte-14g86y1 a.svelte-14g86y1:hover{text-decoration:underline}.invite-message.svelte-14g86y1.svelte-14g86y1{background:rgba(34, 197, 94, 0.1);border:1px solid rgba(34, 197, 94, 0.3);color:#059669;padding:1rem;border-radius:12px;margin-bottom:1.5rem;text-align:center}.invite-message.svelte-14g86y1 .invite-icon.svelte-14g86y1{font-size:2rem;margin-bottom:0.5rem}.invite-message.svelte-14g86y1 h3.svelte-14g86y1{margin:0 0 0.5rem 0;font-size:1.1rem;font-weight:600}.invite-message.svelte-14g86y1 p.svelte-14g86y1{margin:0;font-size:0.875rem;opacity:0.8}.error.svelte-14g86y1.svelte-14g86y1{background:rgba(255, 0, 0, 0.1);border:1px solid rgba(255, 0, 0, 0.3);color:#dc2626;padding:0.75rem;border-radius:8px;margin-bottom:1rem;font-size:0.875rem}.loading-spinner.svelte-14g86y1.svelte-14g86y1{width:20px;height:20px;border:2px solid transparent;border-top:2px solid currentColor;border-radius:50%;animation:svelte-14g86y1-spin 1s linear infinite}@keyframes svelte-14g86y1-spin{to{transform:rotate(360deg)}}",
  map: null
};
const Page = create_ssr_component(($$result, $$props, $$bindings, slots) => {
  let error = "";
  let canvas;
  async function handleInviteCode(inviteCode2, user) {
    try {
      const response = await fetch(`/api/auth/consume_invite/${inviteCode2}`, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${user.access_token}`,
          "Content-Type": "application/json"
        }
      });
      if (response.ok) {
        localStorage.removeItem("pending_invite_code");
        window.location.reload();
      } else {
        const data = await response.json();
        error = data.error || "邀请链接处理失败";
        localStorage.removeItem("pending_invite_code");
        redirectToRolePage(user);
      }
    } catch (err) {
      console.error("处理邀请码失败:", err);
      localStorage.removeItem("pending_invite_code");
      redirectToRolePage(user);
    }
  }
  supabase.auth.onAuthStateChange(async (event, session) => {
    if (event === "SIGNED_IN" && session?.user) {
      const pendingInviteCode = localStorage.getItem("pending_invite_code");
      if (pendingInviteCode) {
        await handleInviteCode(pendingInviteCode, session.user);
      } else {
        redirectToRolePage(session.user);
      }
    }
  });
  $$result.css.add(css);
  return `${$$result.head += `<!-- HEAD_svelte-1ftgmbl_START -->${$$result.title = `<title>百刀会 - 登录</title>`, ""}<meta name="description" content="即将跃迁到百刀会"><!-- HEAD_svelte-1ftgmbl_END -->`, ""}  <canvas class="starfield svelte-14g86y1"${add_attribute("this", canvas, 0)}></canvas> <div class="container svelte-14g86y1"><div class="login-container svelte-14g86y1"> <div class="logo svelte-14g86y1"><img src="/assets/pic/favicon.png" alt="百刀会Logo" class="logo-img svelte-14g86y1"> <div class="logo-fallback svelte-14g86y1" data-svelte-h="svelte-1bxua50">100</div></div> <h1 class="title svelte-14g86y1" data-svelte-h="svelte-iykzic">即将跃迁到百刀会</h1> <p class="subtitle svelte-14g86y1" data-svelte-h="svelte-gtbwaq">Everything Both Nothing</p> ${``} ${error ? `<div class="error svelte-14g86y1">${escape(error)}</div>` : ``} <button ${""} class="google-btn svelte-14g86y1">${`<div class="google-icon svelte-14g86y1" data-svelte-h="svelte-1y4ib42"> <svg width="12" height="12" viewBox="0 0 24 24"><path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"></path><path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"></path><path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"></path><path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"></path></svg></div>`} ${escape("用谷歌登录启动跃迁引擎")}</button> <div class="footer svelte-14g86y1" data-svelte-h="svelte-1ygos0j">😍教主悄悄话💬｜🤑算命申请🔮｜🤩好物推荐🛍️<br><br>
      登录即表示您同意我们的
      <a href="/terms" class="svelte-14g86y1">服务条款</a>
      和
      <a href="/privacy" class="svelte-14g86y1">隐私政策</a></div></div></div>`;
});
export {
  Page as default
};
