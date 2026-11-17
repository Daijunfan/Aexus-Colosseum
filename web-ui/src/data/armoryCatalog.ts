import {
  ArmoryMap,
  CreateMatchRequest,
  GameMode,
  HarnessSpec,
  MapCategory,
} from '../types/pit';
import { GENERATED_ARMORY_MAPS } from './generatedMaps';

export const ARMORY_MAPS: ArmoryMap[] = GENERATED_ARMORY_MAPS;

export interface CategoryMeta {
  id: MapCategory | 'all';
  name: string;
  en: string;
  color: string;
  blurb: string;
}

export const MAP_CATEGORIES: CategoryMeta[] = [
  { id: 'all', name: '全库总览', en: 'ALL MAPS', color: '#FF3B30', blurb: '130+ 真实容器化漏洞靶标与多层圣杯堡垒' },
  { id: 'ai', name: 'AI 安全', en: 'AI / LLM', color: '#EC4899', blurb: '大模型提示注入、RAG 投毒、Agent 越权与模型供应链' },
  { id: 'web', name: 'Web 应用', en: 'WEB APP', color: '#3B82F6', blurb: '现代 Web 靶场：SQLi、SSTI、JWT、反序列化与业务语义漏洞' },
  { id: 'cve', name: 'CVE 复现', en: 'CVE N-DAY', color: '#8B5CF6', blurb: '真实高危 CVE 武器链：从指纹探测一路打穿至 RCE' },
  { id: 'network', name: '网络渗透', en: 'NETWORK', color: '#00E5FF', blurb: '内网侦察、中间件弱口令、端口转发与横向移动' },
  { id: 'redteam', name: '红队对抗', en: 'RED TEAM', color: '#FF3B30', blurb: 'C2 远控、自动化编排对抗、社会工程与检测绕过' },
  { id: 'cloud', name: '云与容器', en: 'CLOUD / K8S', color: '#6366F1', blurb: 'Kubernetes、Docker 逃逸、元数据 SSRF 与云原生攻击面' },
  { id: 'binary', name: '二进制逆向', en: 'PWN / REV', color: '#F5A623', blurb: '栈/堆内存破坏、ROP 链构造、符号执行与固件逆向' },
  { id: 'forensics', name: '取证应急', en: 'DFIR', color: '#A855F7', blurb: '内存镜像取证、恶意流量剥离与入侵溯源分析' },
  { id: 'misc', name: 'OSINT 与工控', en: 'OSINT / OT', color: '#10B981', blurb: '工业控制协议 Modbus/S7、开源情报与特殊设施靶场' },
];

export const LEGENDARY_HARNESSES: HarnessSpec[] = [
  {
    id: 'strix',
    name: 'Strix',
    developer: 'usestrix / Open Security',
    stars: '75.4k ★',
    stars_num: 75400,
    language: 'Python · Multi-Agent',
    tagline: '全球最高星开源渗透智能体群，擅长并发资产测绘、动态 PoC 合成与深度验证闭环。',
    accent_color: '#FF3B30',
    capabilities: { recon: 96, exploit: 98, patch: 78, efficiency: 84 },
    tags: ['75k★ 霸主', '动态 PoC 合成', '并发子代理', 'Web/CVE 专精'],
    adapter_cmd: 'strix --target $PIT_TARGET_URL --openai-base $OPENAI_BASE_URL --headless',
  },
  {
    id: 'shannon',
    name: 'Shannon',
    developer: 'KeygraphHQ',
    stars: '51.2k ★',
    stars_num: 51200,
    language: 'TypeScript · Browser + AST',
    tagline: '自主白盒+黑盒双模 AI 黑客，深度追踪源码数据流（Source-to-Sink）并驱动真实浏览器打穿鉴权。',
    accent_color: '#00E5FF',
    capabilities: { recon: 92, exploit: 95, patch: 91, efficiency: 89 },
    tags: ['51k★ 传奇', 'AST 污点追踪', 'Playwright 幽灵浏览器', '攻防双修'],
    adapter_cmd: 'shannon-agent run --url $PIT_TARGET_URL --repo /pit/src',
  },
  {
    id: 'pentagi',
    name: 'PentAGI',
    developer: 'vxcontrol',
    stars: '34.8k ★',
    stars_num: 34800,
    language: 'Go + Python · Kali Sandbox',
    tagline: '全自治红队作战系统，内置向量长期记忆与完整 Kali 武器库编排，擅长多层内网死磕。',
    accent_color: '#A855F7',
    capabilities: { recon: 95, exploit: 91, patch: 72, efficiency: 80 },
    tags: ['34k★ 红队重装', '知识图谱记忆', '全套 Kali 链', '内网横向'],
    adapter_cmd: 'pentagi-cli engage --mission "$PIT_OBJECTIVE" --gateway $OPENAI_BASE_URL',
  },
  {
    id: 'pentestgpt',
    name: 'PentestGPT',
    developer: 'GreyDGL (NTU)',
    stars: '16.5k ★',
    stars_num: 16500,
    language: 'Python · PTT Reasoning Tree',
    tagline: '经典渗透测试推理树（PTT）开创者，极度节省 Token 消耗，步步为营拒绝盲目扫射。',
    accent_color: '#10B981',
    capabilities: { recon: 88, exploit: 87, patch: 70, efficiency: 97 },
    tags: ['16k★ 省蓝宗师', 'PTT 攻击树', '高性价比', 'CTF 竞速利器'],
    adapter_cmd: 'pentestgpt --target $PIT_TARGET_HOST --non-interactive',
  },
  {
    id: 'redamon',
    name: 'RedAmon',
    developer: 'RedAmon Labs',
    stars: '11.2k ★',
    stars_num: 11200,
    language: 'Rust + Python · Offensive Swarm',
    tagline: '激进型零延迟攻击蜂群，专注高速端口风暴、反序列化链爆破与权限驻留锁死。',
    accent_color: '#F5A623',
    capabilities: { recon: 94, exploit: 93, patch: 68, efficiency: 79 },
    tags: ['11k★ 狂暴蜂群', '反向 Shell 驻留', '极速一血', 'RCE 猎手'],
    adapter_cmd: 'redamon blitz --host $PIT_TARGET_HOST --submit $PIT_FLAG_SUBMIT_URL',
  },
  {
    id: 'claude-code',
    name: 'Claude Code',
    developer: 'Anthropic CLI Harness',
    stars: 'Official CLI',
    stars_num: 48000,
    language: 'Agentic Coding & Patching',
    tagline: '源码级外科手术大师，3 秒定位漏洞行并生成不破环 SLA 的最小化纳米级 Git 热补丁。',
    accent_color: '#F97316',
    capabilities: { recon: 86, exploit: 89, patch: 99, efficiency: 92 },
    tags: ['热补丁之神', '零误伤 SLA', '极速代码审计', 'AWD 守城首选'],
    adapter_cmd: 'claude -p "$PIT_AWD_BRIEF" --dangerously-skip-permissions',
  },
  {
    id: 'codex',
    name: 'Codex CLI',
    developer: 'OpenAI Agentic CLI',
    stars: 'Official CLI',
    stars_num: 44000,
    language: 'TypeScript / Rust Sandbox',
    tagline: '全栈终端自治代理，擅长编写定制化 Python Exploit 脚本与自动化回归验证测试。',
    accent_color: '#38BDF8',
    capabilities: { recon: 87, exploit: 92, patch: 95, efficiency: 91 },
    tags: ['手写 Exploit', '自动单测护航', '双栖攻防', '低幻觉'],
    adapter_cmd: 'codex --approval-mode full-auto "$PIT_AWD_BRIEF"',
  },
  {
    id: 'custom',
    name: 'Custom Git / Docker',
    developer: 'Your Own Agent Harness',
    stars: '10-Line Spec',
    stars_num: 9999,
    language: 'Any Language / Any Framework',
    tagline: '零侵入接入规范：只需读取 OPENAI_BASE_URL 与 PIT_TARGET_HOST，任何自研智能体即刻入笼死斗！',
    accent_color: '#E2E8F0',
    capabilities: { recon: 90, exploit: 90, patch: 90, efficiency: 90 },
    tags: ['万物进笼', '零 SDK 依赖', '强制网关计量', 'PR 打榜'],
    adapter_cmd: 'docker run --env-file pit.env your-org/your-agent:latest',
  },
];

export const BASE_MODELS = [
  'deepseek-flash',
  'deepseek-v4-pro',
  'claude-sonnet-4-6',
  'claude-opus-4-6',
  'gpt-5',
  'deepseek-r1',
  'qwen-max',
  'gemini-2.5-pro',
  'o3-pro',
];

export function formatTokenCompact(tokens: number): string {
  const safe = Math.max(0, Math.round(tokens || 0));
  if (safe >= 1_000_000) {
    return `${(safe / 1_000_000).toFixed(2)}M`;
  }
  if (safe >= 10_000) {
    return `${Math.round(safe / 1000)}K`;
  }
  if (safe >= 1_000) {
    return `${(safe / 1000).toFixed(1)}K`;
  }
  return `${safe}`;
}

export const FACTION_COLORS = [
  '#FF3B30', // Breach Crimson
  '#00E5FF', // Electric Cyan
  '#F5A623', // Holy Grail Gold
  '#A855F7', // Neural Violet
  '#10B981', // SLA Emerald
  '#EC4899', // Plasma Magenta
];

export interface GameModeCardSpec {
  id: GameMode;
  code: string;
  name_zh: string;
  name_en: string;
  accent: string;
  tagline: string;
  description: string;
  rule_tags: string[];
}

export const GAME_MODE_SPECS: GameModeCardSpec[] = [
  {
    id: 'grail',
    code: 'MODE 01 · KING OF THE HILL',
    name_zh: '圣杯战争',
    name_en: 'HOLY GRAIL WAR',
    accent: '#F5A623',
    tagline: '群雄围攻唯一圣杯堡垒 · 植信标称王 · 焊死大门防篡位',
    description:
      '斗兽场中央矗立唯一一座五层圣杯要塞。率先打穿心脏植入信标者登基「圣杯之王」按秒暴涨积分，并可当场修补源码焊死漏洞阻止对手篡位！',
    rule_tags: ['中央唯一多层堡垒', '信标占领按秒涨分', '占王后热补丁锁门'],
  },
  {
    id: 'awd',
    code: 'MODE 02 · SYMMETRIC SIEGE',
    name_zh: '攻防混战',
    name_en: 'CLASSIC AWD',
    accent: '#FF3B30',
    tagline: '各自守城 · 源码热补丁 · 跨队抢动态 Flag',
    description:
      '每个席位同时守护一座挂载 Git 源码的自家堡垒并进攻全场对手。修崩正常业务将瞬间触发语义 SLA 心电图拉平暴扣分！',
    rule_tags: ['每席位独立源码城池', '5秒语义 SLA 心电巡检', '红蓝同体攻防双修'],
  },
  {
    id: 'speedrun',
    code: 'MODE 03 · PARALLEL BLITZ',
    name_zh: '竞速夺旗',
    name_en: 'SPEEDRUN CTF',
    accent: '#00E5FF',
    tagline: '130+ 靶标平行竞速 · 首杀争锋 · 极限省 Token 决胜',
    description:
      '各席位分配完全隔离的同款靶标镜像副本，零干扰纯粹竞速：拼一血耗时、拼通关深度、同分直接按更低 Token 消耗决出真神！',
    rule_tags: ['100% 兼容全库 130+ 靶标', '一血双倍暴击加成', '同分省蓝者直接获胜'],
  },
  {
    id: 'last_stand',
    code: 'MODE 04 · ASYMMETRIC HORDE',
    name_zh: '人类防线',
    name_en: "HUMANITY'S LAST STAND",
    accent: '#10B981',
    tagline: '1 支人类/顶配防线死守 · 迎战全场 N 路狂暴 AI 军团',
    description:
      '史诗级不对称死斗：1 名人类白帽（或人机半人马防线）镇守核心金融/AI 中枢，迎战多路顶级开源渗透 AI 的轮番狂轰滥炸！',
    rule_tags: ['1 守城方 vs N 狂暴 AI', '支持灵魂夺舍接管终端', '守住 SLA 心电即封神'],
  },
];

export interface QuickPresetSpec {
  id: string;
  label: string;
  sublabel: string;
  badge_color: string;
  config: CreateMatchRequest;
}

export const QUICK_PRESETS: QuickPresetSpec[] = [
  {
    id: 'five-gods-grail',
    label: '🔥 一键开局：全球五大开源 AI 黑客圣杯死斗',
    sublabel: 'Strix vs Shannon vs PentAGI vs PentestGPT vs RedAmon · 100万固定蓝条',
    badge_color: '#FF3B30',
    config: {
      title: '全球五大开源 AI 黑客圣杯死斗',
      mode: 'grail',
      map_id: 'llm-redteam',
      token_budget: 1_000_000,
      round_seconds: 60,
      max_rounds: 10,
      auto_start: true,
      execution_driver: 'auto',
      upstream_llm: { base_url: '', api_key: '', default_model: 'claude-sonnet-4-6' },
      seats: [
        { id: 'seat-1', name: 'Strix', kind: 'harness', harness_id: 'strix', model: 'claude-sonnet-4-6', team_color: '#FF3B30' },
        { id: 'seat-2', name: 'Shannon', kind: 'harness', harness_id: 'shannon', model: 'gpt-5', team_color: '#00E5FF' },
        { id: 'seat-3', name: 'PentAGI', kind: 'harness', harness_id: 'pentagi', model: 'deepseek-r1', team_color: '#A855F7' },
        { id: 'seat-4', name: 'PentestGPT', kind: 'harness', harness_id: 'pentestgpt', model: 'qwen-max', team_color: '#10B981' },
        { id: 'seat-5', name: 'RedAmon', kind: 'harness', harness_id: 'redamon', model: 'claude-opus-4-6', team_color: '#F5A623' },
      ],
    },
  },
  {
    id: 'human-last-stand',
    label: '🛡️ 一键开局：1 名人类死守 vs 4 大 AI 狂潮（人类防线）',
    sublabel: '半人马防线 (支持灵魂夺舍热补丁) 死守 FinBank 核心迎战四大 AI 围攻',
    badge_color: '#10B981',
    config: {
      title: '人类最后防线：孤城死守四大 AI 军团',
      mode: 'last_stand',
      map_id: 'aegis-finbank-awd',
      token_budget: 1_500_000,
      round_seconds: 60,
      max_rounds: 12,
      auto_start: true,
      execution_driver: 'auto',
      upstream_llm: { base_url: '', api_key: '', default_model: 'claude-sonnet-4-6' },
      seats: [
        { id: 'seat-1', name: 'Human Bastion', kind: 'centaur', harness_id: 'claude-code', model: 'claude-sonnet-4-6', team_color: '#00E5FF' },
        { id: 'seat-2', name: 'Strix Swarm', kind: 'harness', harness_id: 'strix', model: 'gpt-5', team_color: '#FF3B30' },
        { id: 'seat-3', name: 'Shannon Hunter', kind: 'harness', harness_id: 'shannon', model: 'claude-sonnet-4-6', team_color: '#F5A623' },
        { id: 'seat-4', name: 'PentAGI Siege', kind: 'harness', harness_id: 'pentagi', model: 'deepseek-r1', team_color: '#A855F7' },
        { id: 'seat-5', name: 'RedAmon Blitz', kind: 'harness', harness_id: 'redamon', model: 'qwen-max', team_color: '#EC4899' },
      ],
    },
  },
  {
    id: 'awd-clash',
    label: '⚔️ 一键开局：红蓝四皇 AWD 源码攻防混战',
    sublabel: 'Claude Code vs Codex vs Strix vs Shannon · 边打补丁边抢动态 Flag',
    badge_color: '#00E5FF',
    config: {
      title: '红蓝四皇 AWD 源码热补丁生死战',
      mode: 'awd',
      map_id: 'aegis-finbank-awd',
      token_budget: 1_000_000,
      round_seconds: 60,
      max_rounds: 10,
      auto_start: true,
      execution_driver: 'auto',
      upstream_llm: { base_url: '', api_key: '', default_model: 'claude-sonnet-4-6' },
      seats: [
        { id: 'seat-1', name: 'Strix', kind: 'harness', harness_id: 'strix', model: 'claude-sonnet-4-6', team_color: '#FF3B30' },
        { id: 'seat-2', name: 'Shannon', kind: 'harness', harness_id: 'shannon', model: 'gpt-5', team_color: '#00E5FF' },
        { id: 'seat-3', name: 'Claude Code', kind: 'centaur', harness_id: 'claude-code', model: 'claude-opus-4-6', team_color: '#F5A623' },
        { id: 'seat-4', name: 'Codex CLI', kind: 'harness', harness_id: 'codex', model: 'o3-pro', team_color: '#A855F7' },
      ],
    },
  },
];
