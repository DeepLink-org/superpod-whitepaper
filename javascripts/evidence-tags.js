(function() {
  const TAG_MAP = {
    "事实": {
      className: "evidence-token-fact",
      title: "公开可核验事实"
    },
    "验证": {
      className: "evidence-token-verified",
      title: "可复核的实验或仿真结果"
    },
    "归纳": {
      className: "evidence-token-inductive",
      title: "多源工程归纳"
    },
    "研判": {
      className: "evidence-token-judgment",
      title: "前瞻研判或方向判断"
    }
  };

  const TAG_PATTERN = /【(事实|验证|归纳|研判)】/g;

  function shouldSkip(node) {
    const parent = node.parentElement;
    if (!parent) return true;
    if (!node.textContent || !node.textContent.includes("【")) return true;

    return Boolean(
      parent.closest(
        "code, pre, script, style, textarea, .evidence-token, .md-nav, .md-header, .md-sidebar"
      )
    );
  }

  function replaceInTextNode(node) {
    const text = node.textContent;
    TAG_PATTERN.lastIndex = 0;

    if (!TAG_PATTERN.test(text)) return;

    const fragment = document.createDocumentFragment();
    let lastIndex = 0;

    TAG_PATTERN.lastIndex = 0;
    text.replace(TAG_PATTERN, (match, label, offset) => {
      if (offset > lastIndex) {
        fragment.appendChild(document.createTextNode(text.slice(lastIndex, offset)));
      }

      const span = document.createElement("span");
      span.className = `evidence-token ${TAG_MAP[label].className}`;
      span.textContent = "◂";
      span.title = `${label}：${TAG_MAP[label].title}`;
      span.setAttribute("aria-label", `${label}：${TAG_MAP[label].title}`);
      span.setAttribute("data-evidence-label", label);
      span.setAttribute("data-evidence-tooltip", `${label}：${TAG_MAP[label].title}`);
      span.setAttribute("tabindex", "0");
      fragment.appendChild(span);

      lastIndex = offset + match.length;
      return match;
    });

    if (lastIndex < text.length) {
      fragment.appendChild(document.createTextNode(text.slice(lastIndex)));
    }

    node.parentNode.replaceChild(fragment, node);
  }

  function scan(root) {
    const scope = root || document.querySelector(".md-content") || document.body;
    const walker = document.createTreeWalker(scope, NodeFilter.SHOW_TEXT);
    const textNodes = [];

    while (walker.nextNode()) {
      const node = walker.currentNode;
      if (!shouldSkip(node)) {
        textNodes.push(node);
      }
    }

    textNodes.forEach(replaceInTextNode);
  }

  function init() {
    scan();
  }

  window.initEvidenceTags = init;

  init();

  let timeout = null;
  const observer = new MutationObserver(() => {
    if (timeout) clearTimeout(timeout);
    timeout = setTimeout(init, 50);
  });

  observer.observe(document.body, { childList: true, subtree: true });

  if (typeof document$ !== "undefined") {
    document$.subscribe(() => {
      setTimeout(init, 50);
    });
  }
})();
