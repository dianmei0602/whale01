(() => {
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  const revealItems = [...document.querySelectorAll("[data-reveal], [data-shutter]")];
  if (reduceMotion || !("IntersectionObserver" in window)) {
    revealItems.forEach((item) => item.classList.add("is-in"));
  } else {
    const revealObserver = new IntersectionObserver((entries) => {
      for (const entry of entries) {
        if (!entry.isIntersecting) continue;
        entry.target.classList.add("is-in");
        revealObserver.unobserve(entry.target);
      }
    }, { rootMargin: "0px 0px -12% 0px", threshold: 0.08 });
    revealItems.forEach((item) => revealObserver.observe(item));
  }

  const processSteps = [...document.querySelectorAll("[data-process-step]")];
  const processNodes = [...document.querySelectorAll("[data-process-node]")];
  const trackProgress = document.querySelector("[data-track-progress]");

  const setActiveProcess = (index) => {
    processSteps.forEach((step, stepIndex) => step.classList.toggle("is-active", stepIndex === index));
    processNodes.forEach((node, nodeIndex) => node.classList.toggle("is-active", nodeIndex === index));
    if (trackProgress) {
      const ratio = processNodes.length <= 1 ? 0 : index / (processNodes.length - 1);
      trackProgress.style.height = `${Math.max(0, ratio * 100)}%`;
    }
  };

  if ("IntersectionObserver" in window && processSteps.length) {
    const processObserver = new IntersectionObserver((entries) => {
      const visible = entries
        .filter((entry) => entry.isIntersecting)
        .sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
      if (visible) setActiveProcess(Number(visible.target.dataset.processStep));
    }, { rootMargin: "-38% 0px -38% 0px", threshold: [0, 0.15, 0.4, 0.7] });
    processSteps.forEach((step) => processObserver.observe(step));
  }

  const skills = {
    schedule: {
      name: "日程与提醒",
      count: "9 项工具",
      question: "“明天下午三点提醒我取快递。”",
      path: ["理解时间", "生成预览", "用户确认", "EventKit 写入"],
      boundary: "修改或删除必须先取得记录 ID。写入生成预览，等待界面确认；未指定时间不会被模型擅自补齐。",
      tools: "create_reminder · list_reminders · update_reminder · delete_reminder · list_calendar_events · find_free_slots · create_calendar_event · update_calendar_event · delete_calendar_event"
    },
    travel: {
      name: "出行",
      count: "4 项工具",
      question: "“帮我找附近安静一点的咖啡店。”",
      path: ["读取定位", "搜索地点", "计算距离", "交给地图"],
      boundary: "当前位置、天气、地点和导航必须来自本轮真实工具。打开地图只表示已交接，不说路线已经开始或已经到达。",
      tools: "get_weather · get_current_location · search_places · open_navigation"
    },
    research: {
      name: "研究",
      count: "6 项工具",
      question: "“比较三家 AI 公司最近的产品节奏，给出依据。”",
      path: ["拆问题", "多角度搜索", "URL 去重", "按时间与来源复核"],
      boundary: "复杂问题优先多源研究；精确数字与强时效结论继续读原文。来源冲突要说明，证据不足时不补写。",
      tools: "search_web · research_web · fetch_web_content · search_merchant_prices · get_tech_news · get_game_rank"
    },
    finance: {
      name: "行情",
      count: "7 项工具",
      question: "“看一下比亚迪今天的主力资金和最近走势。”",
      path: ["搜索证券", "读取行情", "读取资金", "标注延迟"],
      boundary: "价格、涨跌、成交时间和资金数据必须来自本轮工具。延迟未知就写未知，不预测走势，也不提供买卖建议。",
      tools: "get_stock_quote · search_stock · get_stock_kline · get_stock_intraday · add_to_watchlist · remove_from_watchlist · list_watchlist"
    },
    music: {
      name: "音乐",
      count: "8 项工具",
      question: "“继续播放刚才找到的那张专辑。”",
      path: ["搜索候选", "保留播放引用", "播放器响应", "读取真实状态"],
      boundary: "必须原样使用本轮候选 ID。只有播放器进入 playing 才能说正在播放；打开网易云不等于读取账号或歌单。",
      tools: "search_music_library · play_music · play_music_album · open_netease_music · pause_music · resume_music · skip_music_track · get_playback_state"
    },
    messaging: {
      name: "消息",
      count: "1 项工具",
      question: "“给张三准备一条说明明天晚到的短信。”",
      path: ["确认联系人", "生成草稿", "打开系统界面", "以系统回调为准"],
      boundary: "联系人来自真实验证；候选不唯一时让用户选择。只准备草稿，不把打开编辑器说成已经发送。",
      tools: "prepare_message"
    },
    memory: {
      name: "记忆",
      count: "3 项工具",
      question: "“以后回答简洁一点，记住这个偏好。”",
      path: ["识别明确意图", "读取相关偏好", "保存一条最小事实", "后续按偏好辅助"],
      boundary: "只保存用户明确表达的偏好。网页内容、一次性指令或模型推断不会自动变成长期记忆。",
      tools: "list_memory · set_memory · delete_memory"
    },
    health: {
      name: "健康",
      count: "1 项工具",
      question: "“我今天走了多少步？”",
      path: ["检查授权", "读取指标", "区分无数据与零值", "给出摘要"],
      boundary: "只读取用户已授权的指标，区分无权限、无数据和零值，不做医疗诊断。",
      tools: "get_activity_summary"
    },
    writing: {
      name: "写作",
      count: "0 项工具",
      question: "“把这段工作说明改得更清楚。”",
      path: ["识别受众", "确认目的", "重组信息", "输出可直接使用的文本"],
      boundary: "先识别受众、目的、长度与语气。信息不足但可合理完成时直接给可用文本，不只讲写作方法。",
      tools: "无原生工具；由模型在当前上下文内完成"
    },
    coding: {
      name: "技术",
      count: "0 项工具",
      question: "“这个 Swift 并发报错怎么定位？”",
      path: ["识别栈", "复现问题", "对照版本与错误", "给出验证步骤"],
      boundary: "先识别技术栈、约束和失败点。需要外部版本或报错资料时联网核对，不能只给泛泛建议。",
      tools: "无专用工具；可按需要调用研究 Skill 的网页能力"
    },
    entertainment: {
      name: "娱乐",
      count: "0 项工具",
      question: "“推荐几个适合周末玩的合作游戏。”",
      path: ["理解偏好", "结合真实资料", "说明推荐理由", "避免编造榜单"],
      boundary: "推荐要解释理由，明确基于真实资料或用户偏好，不编造榜单、价格和库存。",
      tools: "无专用工具；可按需要调用研究 Skill 的网页能力"
    },
    general: {
      name: "通用",
      count: "0 项工具",
      question: "“解释一下多步 Agent 为什么会失败。”",
      path: ["理解问题", "组织答案", "检查事实边界", "直接回答"],
      boundary: "稳定知识可以直接回答；需要当前数据、外部核实或设备操作时，再选择对应 Skill 和 Tool。",
      tools: "无工具；不请求权限，也不伪造实时数据"
    }
  };

  const skillButtons = [...document.querySelectorAll("[data-skill]")];
  const skillName = document.getElementById("skill-name");
  const skillCount = document.getElementById("skill-count");
  const skillQuestion = document.getElementById("skill-question");
  const skillPath = document.getElementById("skill-path");
  const skillBoundary = document.getElementById("skill-boundary");
  const skillTools = document.getElementById("skill-tools");

  const renderSkill = (key) => {
    const item = skills[key];
    if (!item) return;
    skillButtons.forEach((button) => {
      button.setAttribute("aria-pressed", String(button.dataset.skill === key));
    });
    skillName.textContent = item.name;
    skillCount.textContent = item.count;
    skillQuestion.textContent = item.question;
    skillBoundary.textContent = item.boundary;
    skillTools.textContent = item.tools;
    skillPath.replaceChildren();
    item.path.forEach((label, index) => {
      const span = document.createElement("span");
      span.textContent = label;
      skillPath.append(span);
      if (index < item.path.length - 1) {
        skillPath.append(document.createElement("i"));
      }
    });
  };

  skillButtons.forEach((button) => {
    button.addEventListener("click", () => renderSkill(button.dataset.skill));
  });
})();
