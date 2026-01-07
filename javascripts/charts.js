(function() {
  // console.log('[SuperPod Charts] Script loaded. Observer active.');

  const renderChart = (el) => {
    if (el.getAttribute('data-chart-processed')) return;
    
    try {
      // 提取 JSON
      let jsonString = '';
      if (el.tagName === 'CODE') {
        jsonString = el.textContent;
      } else {
        const code = el.querySelector('code');
        if (code) jsonString = code.textContent;
        else jsonString = el.textContent;
      }

      jsonString = jsonString.trim();
      if (!jsonString.startsWith('{')) return;
      
      const spec = JSON.parse(jsonString);
      
      // 创建容器
      const container = document.createElement('div');
      container.className = 'vega-chart-container';
      container.style.width = '100%';
      container.style.overflowX = 'auto';
      container.style.display = 'flex';           // 启用 Flex 布局
      container.style.justifyContent = 'center';  // 水平居中
      container.style.margin = '20px 0';          // 增加上下间距
      
      // 查找替换目标
      let target = el;
      if (target.tagName === 'CODE') target = target.parentElement; // pre
      if (target.parentElement && target.parentElement.classList.contains('highlight')) target = target.parentElement;
      
      if (target.parentNode) {
        target.parentNode.replaceChild(container, target);
        // actions: false 隐藏工具条
        vegaEmbed(container, spec, { actions: false, renderer: 'svg' }).catch(err => console.error('[SuperPod Charts] Vega error:', err));
        el.setAttribute('data-chart-processed', 'true');
        // console.log('[SuperPod Charts] Rendered one chart');
      }
    } catch (e) {
      // console.warn('Not a chart JSON', e);
    }
  };

  const scan = () => {
    const candidates = document.querySelectorAll('.language-vegalite, .vegalite');
    // console.log(`[SuperPod Charts] Scanning... Found ${candidates.length} candidates.`);
    
    if (candidates.length > 0) {
        candidates.forEach(renderChart);
    }
  };

  // 暴露全局函数，方便调试
  window.initSuperPodCharts = scan;

  // 1. 立即尝试
  scan();

  // 2. 监听 DOM 变化 (针对 EncryptContent 解密过程)
  let timeout = null;
  const observer = new MutationObserver((mutations) => {
    if (timeout) clearTimeout(timeout);
    timeout = setTimeout(scan, 100);
  });
  
  observer.observe(document.body, { childList: true, subtree: true });
  
  // 3. 订阅 MkDocs 事件
  if (typeof document$ !== 'undefined') {
    document$.subscribe(() => {
      setTimeout(scan, 100);
    });
  }
})();
