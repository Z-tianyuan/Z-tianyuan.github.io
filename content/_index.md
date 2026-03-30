---
title: "Welcome"
type: "docs"
---

<style>
/* 1. 彻底干掉主题自带的所有干扰元素（侧边栏、移动端顶部栏、底部栏） */
aside.book-menu, aside.book-toc, header.book-header, footer.book-footer {
  display: none !important;
}

/* 2. 剥夺主题给文章容器加的默认宽度和边距限制 */
.book-page, .markdown {
  max-width: 100% !important;
  margin: 0 !important;
  padding: 0 !important;
}

/* 3. 核心魔法：我们自己建一个不受主题控制的“无敌全屏盒子” */
.my-splash-screen {
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  min-height: 100vh; /* 强制盒子的高度等于屏幕可视高度 */
  width: 100%;
  box-sizing: border-box;
  padding-bottom: 0vh; /* 稍微把内容往上托一点点，符合人眼的视觉中心 */
}
</style>

<div class="my-splash-screen">

  <img src="/img/avatar.jpg" alt="Z-tianyuan Avatar" style="width: 160px; height: 160px; border-radius: 50%; object-fit: cover; box-shadow: 0 10px 30px rgba(0,0,0,0.6); margin-bottom: 25px; border: 4px solid #444;">

  <h1 style="font-size: 3.5rem; margin-bottom: 15px; color: #fff; font-weight: bold; letter-spacing: 2px; border: none;">Z-tianyuan</h1>

  <p style="color: #bbb; font-size: 1.25rem; line-height: 1.8; margin-bottom: 40px; max-width: 700px; text-align: center;">
    你好，我是 Z-tianyuan。<br>
    网络工程大三在读 / 🛡️ 专注网络威胁检测与漏洞挖掘 / 🤖 AI 模型探索中
  </p>

  <div style="font-size: 1.2rem; margin-bottom: 50px;">
    <a href="https://github.com/Z-tianyuan" target="_blank" style="margin: 0 15px; color: #5cb85c; text-decoration: none; border-bottom: 2px dashed #5cb85c; padding-bottom: 2px;">GitHub 主页</a>
    <a href="mailto:你的邮箱@example.com" style="margin: 0 15px; color: #5cb85c; text-decoration: none; border-bottom: 2px dashed #5cb85c; padding-bottom: 2px;">Email 联系</a>
  </div>

  <div>
    <a href="/posts/" style="display: inline-block; padding: 12px 35px; font-size: 1.1rem; font-weight: bold; color: #fff; background-color: #007bff; border-radius: 30px; text-decoration: none; box-shadow: 0 4px 15px rgba(0, 123, 255, 0.4); transition: transform 0.2s;" onmouseover="this.style.transform='scale(1.05)';" onmouseout="this.style.transform='scale(1)';">
      👉 进入我的实战知识库
    </a>
  </div>
</div>