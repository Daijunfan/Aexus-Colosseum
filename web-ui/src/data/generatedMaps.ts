import { ArmoryMap } from "../types/pit";

export const GENERATED_ARMORY_MAPS: ArmoryMap[] = [
  {
    "id": "llm-redteam",
    "name": "Aegis AI Vault · 圣杯红队中枢",
    "subtitle": "多层 AI Agent + Jinja2 SSTI + Prompt Vault",
    "category": "ai",
    "difficulty": 4,
    "summary": "旗舰五层圣杯靶标：结合 RAG 提示词注入、工具调用越权、Jinja2 服务端模板注入与 PostgreSQL 机密金库，原生支持 Git 源码热补丁缝合。",
    "tags": [
      "LLM Agent",
      "Prompt Injection",
      "Jinja2 SSTI",
      "AWD 源码热补丁",
      "Grail 5-Layer"
    ],
    "mitre": [
      "T1190",
      "T1059",
      "T1552"
    ],
    "ports": [
      5000,
      8080,
      5432
    ],
    "ram_mb": 2048,
    "supports_awd_patch": true,
    "source": "pit-featured"
  },
  {
    "id": "aegis-finbank-awd",
    "name": "FinBank Core Twin · 金融核心双生堡垒",
    "subtitle": "高并发转账语义 SLA + SQLi + JWT 伪造 + RCE",
    "category": "web",
    "difficulty": 4,
    "summary": "专为 AWD 攻防混战与人类防线打造的数字孪生核心交易系统。裁判每 5 秒模拟真实开户、鉴权与跨行转账，粗暴封端口将瞬间触发 SLA 心电图拉平。",
    "tags": [
      "AWD 旗舰",
      "语义 SLA",
      "JWT 越权",
      "SQL 注入",
      "反序列化"
    ],
    "mitre": [
      "T1190",
      "T1078",
      "T1059"
    ],
    "ports": [
      8080,
      6379,
      3306
    ],
    "ram_mb": 2048,
    "supports_awd_patch": true,
    "source": "pit-featured"
  },
  {
    "id": "k8s-citadel-grail",
    "name": "Citadel K8s Mesh · 云原生圣杯要塞",
    "subtitle": "Ingress 穿透 + 容器逃逸 + IAM 凭证窃取",
    "category": "cloud",
    "difficulty": 5,
    "summary": "云原生多层攻防要塞：从暴露的网关 SSRF 切入 Pod 元数据凭证，横向突破 Redis 集群并争夺宿主机级圣杯信标。",
    "tags": [
      "Kubernetes",
      "SSRF",
      "容器逃逸",
      "eBPF 焦点",
      "圣杯死斗"
    ],
    "mitre": [
      "T1611",
      "T1552",
      "T1068"
    ],
    "ports": [
      8443,
      6443,
      2379
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "pit-featured"
  },
  {
    "id": "caldera",
    "name": "MITRE Caldera",
    "subtitle": "自动化 adversary emulation",
    "category": "redteam",
    "difficulty": 3,
    "summary": "MITRE 官方自动化对抗平台，用 ATT&CK 能力编排红队行动，并可与蓝队检测体系联动做紫队验证。",
    "tags": [
      "MITRE",
      "ATT&CK",
      "C2",
      "自动化",
      "对抗"
    ],
    "mitre": [
      "T1059",
      "T1053",
      "T1071",
      "T1105"
    ],
    "ports": [
      8888
    ],
    "ram_mb": 6144,
    "supports_awd_patch": false,
    "source": "curated"
  },
  {
    "id": "dvga",
    "name": "Damn Vulnerable GraphQL",
    "subtitle": "GraphQL 专项靶场",
    "category": "web",
    "difficulty": 3,
    "summary": "面向 GraphQL 的实战靶场，覆盖内省、注入、拒绝服务、批量查询与 IDOR 等 API 攻击面。",
    "tags": [
      "GraphQL",
      "API",
      "注入",
      "越权",
      "批量查询"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      5013
    ],
    "ram_mb": 2048,
    "supports_awd_patch": true,
    "source": "curated"
  },
  {
    "id": "dvwa",
    "name": "DVWA",
    "subtitle": "Damn Vulnerable Web Application",
    "category": "web",
    "difficulty": 1,
    "summary": "最经典的教学型 Web 靶场，四档难度可调，适合建立从手工测试到自动化利用的完整肌肉记忆。",
    "tags": [
      "PHP",
      "SQL 注入",
      "XSS",
      "文件包含",
      "命令执行"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8081
    ],
    "ram_mb": 2048,
    "supports_awd_patch": true,
    "source": "curated"
  },
  {
    "id": "forensics",
    "name": "数字取证工作站",
    "subtitle": "内存 / 磁盘 / 流量三录合一",
    "category": "forensics",
    "difficulty": 3,
    "summary": "预装 Volatility3、SleuthKit、Autopsy CLI 工具链、tshark、YARA、binwalk、foremost 的取证分析台。",
    "tags": [
      "Volatility3",
      "SleuthKit",
      "tshark",
      "YARA",
      "binwalk"
    ],
    "mitre": [
      "T1005",
      "T1071"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": false,
    "source": "curated"
  },
  {
    "id": "gophish",
    "name": "GoPhish 钓鱼平台",
    "subtitle": "红队钓鱼演练",
    "category": "redteam",
    "difficulty": 2,
    "summary": "开源钓鱼框架，包含活动管理、邮件模板、落地页与统计面板，适合在授权范围内演练邮件钓鱼全流程。",
    "tags": [
      "钓鱼",
      "邮件",
      "红队",
      "社会工程"
    ],
    "mitre": [
      "T1566",
      "T1204"
    ],
    "ports": [
      3333
    ],
    "ram_mb": 2048,
    "supports_awd_patch": false,
    "source": "curated"
  },
  {
    "id": "juice-shop",
    "name": "OWASP Juice Shop",
    "subtitle": "现代 Web 靶场 · 综合渗透",
    "category": "web",
    "difficulty": 3,
    "summary": "OWASP 官方旗舰靶场，覆盖 OWASP Top 10 的 100+ 挑战，从信息泄露一路打到 RCE 与加密缺陷。",
    "tags": [
      "OWASP",
      "Node.js",
      "SQL 注入",
      "XSS",
      "JWT",
      "业务逻辑"
    ],
    "mitre": [
      "T1190",
      "T1059"
    ],
    "ports": [
      3000
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "curated"
  },
  {
    "id": "metasploitable2",
    "name": "Metasploitable 2",
    "subtitle": "经典 Linux 渗透靶机",
    "category": "network",
    "difficulty": 2,
    "summary": "安全圈最经典的 Linux 靶机之一，开放 FTP、SSH、Telnet、SMB、MySQL、Tomcat 等大量脆弱服务。",
    "tags": [
      "Linux",
      "服务枚举",
      "弱口令",
      "vsftpd",
      "Samba",
      "提权"
    ],
    "mitre": [
      "T1046",
      "T1110",
      "T1210",
      "T1068"
    ],
    "ports": [
      8085,
      8086,
      8022
    ],
    "ram_mb": 4096,
    "supports_awd_patch": false,
    "source": "curated"
  },
  {
    "id": "mutillidae",
    "name": "OWASP Mutillidae II",
    "subtitle": "漏洞大全 · Web 综合靶场",
    "category": "web",
    "difficulty": 2,
    "summary": "覆盖 OWASP Top 10 的自由开源 Web 靶场，内置数十类漏洞与循序渐进的教学提示，适合系统性刷题。",
    "tags": [
      "OWASP",
      "PHP",
      "MySQL",
      "SQL 注入",
      "XSS",
      "LFI"
    ],
    "mitre": [
      "T1190",
      "T1059"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 2048,
    "supports_awd_patch": true,
    "source": "curated"
  },
  {
    "id": "osint",
    "name": "SpiderFoot OSINT",
    "subtitle": "开源情报自动化",
    "category": "misc",
    "difficulty": 2,
    "summary": "自动化开源情报平台，支持域名、IP、邮箱、用户名等 200+ 数据源模块，适合授权范围内的资产测绘训练。",
    "tags": [
      "OSINT",
      "情报",
      "资产发现",
      "社工"
    ],
    "mitre": [
      "T1590",
      "T1589"
    ],
    "ports": [
      5001
    ],
    "ram_mb": 4096,
    "supports_awd_patch": false,
    "source": "curated"
  },
  {
    "id": "ot-lab",
    "name": "工控协议靶场",
    "subtitle": "Modbus / S7 与蜜罐",
    "category": "misc",
    "difficulty": 3,
    "summary": "基于 Conpot 的工控蜜罐与 Modbus 调试环境，练习工控资产识别、协议交互与安全评估。",
    "tags": [
      "ICS",
      "Modbus",
      "Conpot",
      "PLC",
      "蜜罐"
    ],
    "mitre": [
      "T1046",
      "T0836"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 2048,
    "supports_awd_patch": false,
    "source": "curated"
  },
  {
    "id": "pwnbox",
    "name": "PwnBox",
    "subtitle": "二进制利用工作站",
    "category": "binary",
    "difficulty": 3,
    "summary": "预装 pwntools、pwndbg、one_gadget、ROPgadget 的利用工作站，附带 how2heap 学习仓库。",
    "tags": [
      "pwntools",
      "pwndbg",
      "ROP",
      "堆",
      "gdb"
    ],
    "mitre": [
      "T1203"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 6144,
    "supports_awd_patch": false,
    "source": "curated"
  },
  {
    "id": "rev-lab",
    "name": "逆向工程实验室",
    "subtitle": "静态 + 动态分析工具箱",
    "category": "binary",
    "difficulty": 3,
    "summary": "为逆向与符号执行准备的工作站：radare2、angr、Z3、capstone、binwalk、strace 与自编 crackme 套件。",
    "tags": [
      "radare2",
      "angr",
      "Z3",
      "binwalk",
      "Ghidra 兼容"
    ],
    "mitre": [
      "T1027"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": false,
    "source": "curated"
  },
  {
    "id": "sqli-labs",
    "name": "SQLi-Labs",
    "subtitle": "65 关 SQL 注入训练场",
    "category": "web",
    "difficulty": 2,
    "summary": "从联合查询到布尔盲注、时间盲注、报错注入与 WAF 绕过的完整注入训练序列。",
    "tags": [
      "SQL 注入",
      "MySQL",
      "盲注",
      "堆叠注入"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8083
    ],
    "ram_mb": 2048,
    "supports_awd_patch": true,
    "source": "curated"
  },
  {
    "id": "weak-creds",
    "name": "弱口令服务靶机",
    "subtitle": "SSH / FTP 凭据攻击",
    "category": "network",
    "difficulty": 1,
    "summary": "为口令攻击训练准备的双服务靶机：真实 sshd 与 vsftpd，存在可被字典命中的用户与一个 flag 文件。",
    "tags": [
      "Hydra",
      "SSH",
      "FTP",
      "字典",
      "横向"
    ],
    "mitre": [
      "T1110",
      "T1078"
    ],
    "ports": [
      2222,
      2121
    ],
    "ram_mb": 2048,
    "supports_awd_patch": false,
    "source": "curated"
  },
  {
    "id": "webgoat",
    "name": "OWASP WebGoat",
    "subtitle": "交互式 Web 安全课程",
    "category": "web",
    "difficulty": 2,
    "summary": "由 OWASP 维护的交互式教学平台，每关都有讲解、提示与实时判分，适合系统化补齐 Web 漏洞知识图谱。",
    "tags": [
      "Java",
      "OWASP",
      "课程",
      "注入",
      "认证"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8082
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "curated"
  },
  {
    "id": "wrongsecrets",
    "name": "OWASP WrongSecrets",
    "subtitle": "云原生密钥泄露靶场",
    "category": "cloud",
    "difficulty": 3,
    "summary": "以「找 flag」驱动的密钥管理靶场，覆盖硬编码、环境变量、K8s Secret、Vault 与 CI/CD 泄露。",
    "tags": [
      "OWASP",
      "Secret",
      "Kubernetes",
      "云原生",
      "CTF"
    ],
    "mitre": [
      "T1552",
      "T1190"
    ],
    "ports": [
      8084
    ],
    "ram_mb": 4096,
    "supports_awd_patch": false,
    "source": "curated"
  },
  {
    "id": "vulhub-log4shell",
    "name": "Log4Shell",
    "subtitle": "CVE-2021-44228 · JNDI 注入",
    "category": "cve",
    "difficulty": 3,
    "summary": "Apache Log4j2 的 JNDI 查找注入，一次 DNS 回连即可确认，配合 LDAP 服务可直接 RCE。",
    "tags": [
      "Log4j2",
      "JNDI",
      "RCE",
      "Java"
    ],
    "mitre": [
      "T1190",
      "T1059"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-spring4shell",
    "name": "Spring4Shell",
    "subtitle": "CVE-2022-22965 · Spring 参数绑定 RCE",
    "category": "cve",
    "difficulty": 3,
    "summary": "Spring MVC 参数绑定缺陷，在特定 JDK/Tomcat 组合下可通过 class.module.classLoader 改写日志配置写入 WebShell。",
    "tags": [
      "Spring",
      "Java",
      "Tomcat",
      "RCE"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-fastjson",
    "name": "Fastjson 1.2.47",
    "subtitle": "反序列化 RCE 经典链",
    "category": "cve",
    "difficulty": 3,
    "summary": "Fastjson 1.2.47 的 autoType 绕过链，配合 RMI/LDAP 实现远程代码执行。",
    "tags": [
      "Fastjson",
      "反序列化",
      "JNDI",
      "Java"
    ],
    "mitre": [
      "T1190",
      "T1059"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-struts2-s2045",
    "name": "Struts2 S2-045",
    "subtitle": "Content-Type OGNL 注入",
    "category": "cve",
    "difficulty": 3,
    "summary": "Jakarta Multipart 解析器在 Content-Type 头处理中触发 OGNL 表达式执行，是 Struts2 系列最经典的 RCE 之一。",
    "tags": [
      "Struts2",
      "OGNL",
      "RCE",
      "Java"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-struts2-s2057",
    "name": "Struts2 S2-057",
    "subtitle": "命名空间 OGNL 注入",
    "category": "cve",
    "difficulty": 4,
    "summary": "当 alwaysSelectFullNamespace 开启且配置不当时，URL 命名空间被当作 OGNL 求值，可实现稳定 RCE。",
    "tags": [
      "Struts2",
      "OGNL",
      "RCE"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-shiro",
    "name": "Shiro RememberMe 反序列化",
    "subtitle": "CVE-2016-4437 · 硬编码密钥",
    "category": "cve",
    "difficulty": 3,
    "summary": "Shiro 默认 RememberMe 密钥导致攻击者可伪造加密 cookie，配合 gadget 链实现 RCE。",
    "tags": [
      "Shiro",
      "反序列化",
      "CommonsBeanutils",
      "Java"
    ],
    "mitre": [
      "T1190",
      "T1552"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-weblogic-14882",
    "name": "WebLogic 控制台绕过",
    "subtitle": "CVE-2020-14882 · 未授权 RCE",
    "category": "cve",
    "difficulty": 4,
    "summary": "WebLogic 控制台路径穿越绕过认证，结合 CVE-2020-14883 可实现未授权远程代码执行。",
    "tags": [
      "WebLogic",
      "Java",
      "未授权",
      "RCE"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-weblogic-10271",
    "name": "WebLogic WLS-WSAT",
    "subtitle": "CVE-2017-10271 · XMLDecoder 反序列化",
    "category": "cve",
    "difficulty": 3,
    "summary": "WLS-WSAT 组件接收未过滤 XML，XMLDecoder 反序列化导致命令执行，是 WebLogic 最广为人知的漏洞之一。",
    "tags": [
      "WebLogic",
      "XMLDecoder",
      "反序列化",
      "RCE"
    ],
    "mitre": [
      "T1190",
      "T1059"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-jenkins",
    "name": "Jenkins 未授权 RCE",
    "subtitle": "CVE-2018-1000861 · Stapler 路由绕过",
    "category": "cve",
    "difficulty": 4,
    "summary": "Jenkins Stapler 路由解析缺陷允许未授权访问 Groovy 脚本执行端点，直接接管 CI/CD。",
    "tags": [
      "Jenkins",
      "Groovy",
      "CI/CD",
      "RCE"
    ],
    "mitre": [
      "T1190",
      "T1072"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-tomcat",
    "name": "Tomcat PUT 上传",
    "subtitle": "CVE-2017-12615 · 任意文件写入",
    "category": "cve",
    "difficulty": 2,
    "summary": "Tomcat 开启 readonly=false 时，PUT 方法配合路径技巧可写入 JSP WebShell 并执行。",
    "tags": [
      "Tomcat",
      "文件上传",
      "WebShell",
      "Java"
    ],
    "mitre": [
      "T1190",
      "T1505"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-redis-unacc",
    "name": "Redis 未授权访问",
    "subtitle": "写 SSH 公钥 / 定时任务",
    "category": "network",
    "difficulty": 2,
    "summary": "Redis 未设置密码且暴露公网时，可通过写 SSH authorized_keys 或 crontab 实现远程命令执行。",
    "tags": [
      "Redis",
      "未授权",
      "持久化",
      "SSH"
    ],
    "mitre": [
      "T1190",
      "T1053"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-phpmyadmin",
    "name": "phpMyAdmin 文件包含",
    "subtitle": "CVE-2018-12613 · LFI 到 RCE",
    "category": "cve",
    "difficulty": 2,
    "summary": "index.php 的参数校验缺陷导致本地文件包含，结合会话文件可升级为代码执行。",
    "tags": [
      "phpMyAdmin",
      "LFI",
      "文件包含",
      "PHP"
    ],
    "mitre": [
      "T1190",
      "T1005"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-activemq",
    "name": "ActiveMQ 文件写入",
    "subtitle": "CVE-2016-3088 · 任意文件上传",
    "category": "cve",
    "difficulty": 3,
    "summary": "ActiveMQ fileserver 支持任意文件写入，可将 JSP 写入 Web 目录获取 shell。",
    "tags": [
      "ActiveMQ",
      "文件上传",
      "WebShell",
      "Java"
    ],
    "mitre": [
      "T1190",
      "T1505"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-confluence",
    "name": "Confluence 权限提升",
    "subtitle": "CVE-2023-22515 · 创建管理员",
    "category": "cve",
    "difficulty": 3,
    "summary": "Confluence Data Center 的 setup 端点未授权访问，可创建管理员账户接管实例。",
    "tags": [
      "Confluence",
      "未授权",
      "权限提升",
      "Java"
    ],
    "mitre": [
      "T1190",
      "T1078"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-drupal",
    "name": "Drupalgeddon2",
    "subtitle": "CVE-2018-7600 · 表单 API RCE",
    "category": "cve",
    "difficulty": 2,
    "summary": "Drupal 表单 API 对子键过滤不严，导致未认证用户可通过构造请求实现远程代码执行。",
    "tags": [
      "Drupal",
      "PHP",
      "RCE",
      "表单 API"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-solr",
    "name": "Solr Velocity RCE",
    "subtitle": "CVE-2019-17558 · 模板注入",
    "category": "cve",
    "difficulty": 3,
    "summary": "Solr 的 params.resource.loader.enabled 可被外部开启，随后 Velocity 模板注入导致命令执行。",
    "tags": [
      "Solr",
      "Velocity",
      "SSTI",
      "RCE"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-nexus",
    "name": "Nexus Repository RCE",
    "subtitle": "CVE-2019-7238 · EL 注入",
    "category": "cve",
    "difficulty": 3,
    "summary": "Nexus Repository Manager 3 的 extdirect 接口存在表达式注入，可未授权执行命令。",
    "tags": [
      "Nexus",
      "Java",
      "EL 注入",
      "RCE"
    ],
    "mitre": [
      "T1190",
      "T1195"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-elasticsearch",
    "name": "Elasticsearch Groovy RCE",
    "subtitle": "CVE-2015-1427 · 沙箱逃逸",
    "category": "cve",
    "difficulty": 2,
    "summary": "Elasticsearch 1.x 的 Groovy 脚本沙箱可被绕过，攻击者可通过搜索请求执行任意 Java 代码。",
    "tags": [
      "Elasticsearch",
      "Groovy",
      "沙箱逃逸",
      "RCE"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-thinkphp",
    "name": "ThinkPHP 5 RCE",
    "subtitle": "5.x 路由与变量覆盖",
    "category": "cve",
    "difficulty": 2,
    "summary": "ThinkPHP 5.x 因路由解析与变量覆盖问题，可未授权调用任意方法实现命令执行。",
    "tags": [
      "ThinkPHP",
      "PHP",
      "RCE",
      "框架"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-ghostscript",
    "name": "Ghostscript 沙箱绕过",
    "subtitle": "CVE-2018-16509 · 图片处理链攻击",
    "category": "cve",
    "difficulty": 4,
    "summary": "Ghostscript 的 -dSAFER 沙箱绕过，常作为图片上传功能的二次利用链，值得作为供应链攻击案例研究。",
    "tags": [
      "Ghostscript",
      "沙箱绕过",
      "文件上传",
      "RCE"
    ],
    "mitre": [
      "T1203",
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-wordpress-pwnscriptum",
    "name": "WordPress PHPMailer 命令注入",
    "subtitle": "CVE-2016-10033 · 邮件组件 RCE",
    "category": "web",
    "difficulty": 3,
    "summary": "WordPress 4.6 内置的 PHPMailer 在 mail() 发件人地址校验上存在缺陷，构造含引号的地址即可注入额外命令。",
    "tags": [
      "WordPress",
      "PHPMailer",
      "命令注入",
      "RCE"
    ],
    "mitre": [
      "T1190",
      "T1059"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-joomla-20178917",
    "name": "Joomla com_fields SQL 注入",
    "subtitle": "CVE-2017-8917 · 未授权注入",
    "category": "web",
    "difficulty": 2,
    "summary": "Joomla 3.7.0 的 com_fields 组件未对 list[fullordering] 参数做过滤，未授权攻击者可直接注入 SQL。",
    "tags": [
      "Joomla",
      "SQL 注入",
      "PHP",
      "未授权"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-joomla-202323752",
    "name": "Joomla WebService 未授权访问",
    "subtitle": "CVE-2023-23752 · 配置信息泄露",
    "category": "web",
    "difficulty": 1,
    "summary": "Joomla 4.0.0 至 4.2.7 的 WebService API 缺少权限校验，未授权访问 config 接口即可读取数据库等敏感配置。",
    "tags": [
      "Joomla",
      "未授权",
      "信息泄露",
      "API"
    ],
    "mitre": [
      "T1190",
      "T1552"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-cmsms-20199053",
    "name": "CMS Made Simple 盲注",
    "subtitle": "CVE-2019-9053 · 时间盲注",
    "category": "web",
    "difficulty": 2,
    "summary": "CMS Made Simple 2.2.9 的 news 模块 m1_idlist 参数存在未授权时间盲注，可逐字符提取数据库内容。",
    "tags": [
      "CMS Made Simple",
      "SQL 注入",
      "盲注",
      "PHP"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-laravel-20213129",
    "name": "Laravel Ignition RCE",
    "subtitle": "CVE-2021-3129 · 日志伪造反序列化",
    "category": "web",
    "difficulty": 3,
    "summary": "Laravel 开启 debug 模式时，Ignition 的解决方案接口可被诱导写入恶意日志并触发反序列化，从而实现远程代码执行。",
    "tags": [
      "Laravel",
      "Ignition",
      "反序列化",
      "RCE"
    ],
    "mitre": [
      "T1190",
      "T1059"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-php-201911043",
    "name": "PHP-FPM 路径信息 RCE",
    "subtitle": "CVE-2019-11043 · Nginx 配置组合漏洞",
    "category": "web",
    "difficulty": 3,
    "summary": "Nginx 的 fastcgi_split_path_info 配置与 PHP-FPM 的路径解析缺陷叠加，可使攻击者越界写入配置并执行任意代码。",
    "tags": [
      "PHP-FPM",
      "Nginx",
      "RCE",
      "配置缺陷"
    ],
    "mitre": [
      "T1190",
      "T1059"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-node-201714849",
    "name": "Node.js 目录穿越",
    "subtitle": "CVE-2017-14849 · 静态文件读取",
    "category": "web",
    "difficulty": 2,
    "summary": "Node.js 8.5.0 的路径规范化处理存在缺陷，构造带 .. 的静态资源 URL 可读取进程 cwd 之外的任意文件。",
    "tags": [
      "Node.js",
      "目录穿越",
      "信息泄露"
    ],
    "mitre": [
      "T1190",
      "T1005"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-spring-202222947",
    "name": "Spring Cloud Gateway SpEL 注入",
    "subtitle": "CVE-2022-22947 · Actuator 远程代码执行",
    "category": "cve",
    "difficulty": 3,
    "summary": "Spring Cloud Gateway 的 Actuator 端点允许动态添加路由，过滤器参数中的 SpEL 表达式可被直接求值并执行命令。",
    "tags": [
      "Spring Cloud Gateway",
      "SpEL",
      "Actuator",
      "RCE"
    ],
    "mitre": [
      "T1190",
      "T1059"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-fastjson-1224",
    "name": "Fastjson 1.2.24 反序列化",
    "subtitle": "1.2.24 · autoType 远程代码执行",
    "category": "cve",
    "difficulty": 3,
    "summary": "Fastjson 1.2.24 默认开启 autoType，攻击者可指定恶意类并通过 JNDI 或 TemplatesImpl 链实现远程代码执行。",
    "tags": [
      "Fastjson",
      "反序列化",
      "JNDI",
      "Java"
    ],
    "mitre": [
      "T1190",
      "T1059"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-fastjson-1283",
    "name": "Fastjson 1.2.83 绕过",
    "subtitle": "1.2.83 · autoType 限制绕过",
    "category": "cve",
    "difficulty": 4,
    "summary": "Fastjson 1.2.83 对 autoType 做了更严格限制，但特定 gadget 与解析特性仍可构造出可利用的反序列化链。",
    "tags": [
      "Fastjson",
      "反序列化",
      "autoType",
      "绕过"
    ],
    "mitre": [
      "T1190",
      "T1059"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-struts2-s2005",
    "name": "Struts2 S2-005",
    "subtitle": "CVE-2010-1870 · OGNL 沙箱绕过",
    "category": "cve",
    "difficulty": 3,
    "summary": "Struts2 对 OGNL 的 #_memberAccess 等限制可被参数注入绕过，S2-005 因此成为早期 Struts2 RCE 的经典案例。",
    "tags": [
      "Struts2",
      "OGNL",
      "RCE",
      "Java"
    ],
    "mitre": [
      "T1190",
      "T1059"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-redis-20220543",
    "name": "Redis Lua 沙箱逃逸",
    "subtitle": "CVE-2022-0543 · Debian 打包缺陷",
    "category": "network",
    "difficulty": 3,
    "summary": "Debian/Ubuntu 打包的 Redis 未正确清理 Lua 沙箱，攻击者可通过 EVAL 加载动态库执行任意系统命令。",
    "tags": [
      "Redis",
      "Lua",
      "沙箱逃逸",
      "RCE"
    ],
    "mitre": [
      "T1190",
      "T1059"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-mysql-20122122",
    "name": "MySQL 认证绕过",
    "subtitle": "CVE-2012-2122 · 概率性登录成功",
    "category": "network",
    "difficulty": 2,
    "summary": "MySQL/MariaDB 在比较认证哈希时存在缺陷，反复使用错误密码尝试有较大概率被判定为认证成功。",
    "tags": [
      "MySQL",
      "认证绕过",
      "口令攻击"
    ],
    "mitre": [
      "T1110",
      "T1078"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-postgres-20199193",
    "name": "PostgreSQL COPY PROGRAM RCE",
    "subtitle": "CVE-2019-9193 · 超级用户命令执行",
    "category": "network",
    "difficulty": 2,
    "summary": "PostgreSQL 的 COPY TO/FROM PROGRAM 允许超级用户执行任意系统命令，拿到高权限数据库账户即可转为系统 shell。",
    "tags": [
      "PostgreSQL",
      "COPY",
      "RCE",
      "提权"
    ],
    "mitre": [
      "T1190",
      "T1059"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-postgres-20181058",
    "name": "PostgreSQL search_path 提权",
    "subtitle": "CVE-2018-1058 · 函数劫持",
    "category": "network",
    "difficulty": 3,
    "summary": "普通用户可在 public schema 创建同名函数，诱导超级用户执行时因 search_path 顺序被劫持，从而以高权限执行代码。",
    "tags": [
      "PostgreSQL",
      "search_path",
      "权限提升",
      "函数劫持"
    ],
    "mitre": [
      "T1036",
      "T1059"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-nginx-20177529",
    "name": "Nginx Range 整数溢出",
    "subtitle": "CVE-2017-7529 · 内存信息泄露",
    "category": "network",
    "difficulty": 2,
    "summary": "Nginx 处理 Range 请求头时存在整数溢出，构造异常的 Range 范围可在响应中泄露相邻内存中的敏感数据。",
    "tags": [
      "Nginx",
      "整数溢出",
      "信息泄露",
      "Range"
    ],
    "mitre": [
      "T1190",
      "T1005"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-nginx-insecure-config",
    "name": "Nginx 配置错误合集",
    "subtitle": "CRLF 注入 · 目录穿越 · 头覆盖",
    "category": "network",
    "difficulty": 2,
    "summary": "该环境演示 Nginx 常见配置缺陷，包括 CRLF 注入、alias 目录穿越与 add_header 继承问题三类场景。",
    "tags": [
      "Nginx",
      "配置错误",
      "CRLF 注入",
      "目录穿越"
    ],
    "mitre": [
      "T1190",
      "T1005"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-docker-unauthorized",
    "name": "Docker Remote API 未授权",
    "subtitle": "2375 端口 · 容器逃逸",
    "category": "cloud",
    "difficulty": 2,
    "summary": "Docker daemon 暴露未加密的 Remote API 时，攻击者可直接创建特权容器并挂载宿主机根目录，进而接管主机。",
    "tags": [
      "Docker",
      "未授权",
      "Remote API",
      "容器逃逸"
    ],
    "mitre": [
      "T1190",
      "T1610",
      "T1611"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-comfyui-202567303",
    "name": "ComfyUI-Manager 未授权 RCE",
    "subtitle": "CVE-2025-67303 · 任意文件上传",
    "category": "ai",
    "difficulty": 3,
    "summary": "ComfyUI-Manager 的数据目录未受 Web API 访问控制保护，未授权攻击者可上传任意文件并覆盖配置，在默认部署下升级为远程代码执行。",
    "tags": [
      "ComfyUI",
      "AI",
      "未授权",
      "文件上传",
      "RCE"
    ],
    "mitre": [
      "T1190",
      "T1505"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-cups-browsed-202447177",
    "name": "CUPS cups-browsed 命令注入",
    "subtitle": "CVE-2024-47177 · 打印服务远程执行",
    "category": "network",
    "difficulty": 3,
    "summary": "cups-browsed 处理远程打印服务广播时未充分校验属性，攻击者可注册恶意打印机并通过 FoomaticRIPCommandLine 注入命令。",
    "tags": [
      "CUPS",
      "cups-browsed",
      "命令注入",
      "RCE"
    ],
    "mitre": [
      "T1190",
      "T1059"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-httpd-202141773",
    "name": "Apache HTTP Server 路径穿越",
    "subtitle": "CVE-2021-41773 · 路径穿越到 RCE",
    "category": "web",
    "difficulty": 2,
    "summary": "Apache HTTP Server 2.4.49 的路径规范化存在缺陷，攻击者可用 ../ 穿越到文档根之外读取任意文件；若目标启用了 CGI，还可把穿越路径映射到解释器实现命令执行。",
    "tags": [
      "Apache HTTPD",
      "路径穿越",
      "文件读取",
      "RCE"
    ],
    "mitre": [
      "T1190",
      "T1005"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-drupal-20187602",
    "name": "Drupalgeddon 3",
    "subtitle": "CVE-2018-7602 · 已认证 RCE",
    "category": "web",
    "difficulty": 3,
    "summary": "Drupal 7.x/8.x 对 # 的双重 URL 编码过滤不严，已认证用户可绕过 sanitize() 校验并构造请求触发远程代码执行。",
    "tags": [
      "Drupal",
      "PHP",
      "RCE",
      "表单 API"
    ],
    "mitre": [
      "T1190",
      "T1059"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-elfinder-202132682",
    "name": "elFinder 命令注入",
    "subtitle": "CVE-2021-32682 · ZIP 参数注入",
    "category": "web",
    "difficulty": 3,
    "summary": "elFinder 2.1.48 及更早版本在归档/解档操作中未正确转义 ZIP 参数，攻击者可注入额外命令并在 PHP connector 所在主机执行。",
    "tags": [
      "elFinder",
      "命令注入",
      "文件管理",
      "PHP"
    ],
    "mitre": [
      "T1190",
      "T1059"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-showdoc-cnvd-202026585",
    "name": "ShowDoc 未授权文件上传",
    "subtitle": "CNVD-2020-26585 · WebShell 上传",
    "category": "web",
    "difficulty": 2,
    "summary": "ShowDoc 2.8.7 之前版本的图片上传接口缺少鉴权与文件类型校验，未授权攻击者可上传 PHP 文件并执行任意代码。",
    "tags": [
      "ShowDoc",
      "文件上传",
      "WebShell",
      "PHP"
    ],
    "mitre": [
      "T1190",
      "T1505"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-grafana-202143798",
    "name": "Grafana 插件路径穿越",
    "subtitle": "CVE-2021-43798 · 任意文件读取",
    "category": "web",
    "difficulty": 2,
    "summary": "Grafana 8.x 的插件资源接口未正确校验路径，未授权攻击者可借助 ../ 读取服务器任意文件，包括配置与凭据。",
    "tags": [
      "Grafana",
      "路径穿越",
      "文件读取",
      "未授权"
    ],
    "mitre": [
      "T1190",
      "T1005"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-uwsgi-20187490",
    "name": "uWSGI PHP 目录穿越",
    "subtitle": "CVE-2018-7490 · DOCUMENT_ROOT 逃逸",
    "category": "web",
    "difficulty": 2,
    "summary": "uWSGI 的 PHP 插件在 2.0.17 之前未正确处理 DOCUMENT_ROOT，使用 ..%2f 可读取甚至执行文档根之外的文件。",
    "tags": [
      "uWSGI",
      "PHP",
      "目录穿越",
      "文件读取"
    ],
    "mitre": [
      "T1190",
      "T1005"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-tomcat-ghostcat",
    "name": "Tomcat Ghostcat",
    "subtitle": "CVE-2020-1938 · AJP 文件读取/包含",
    "category": "cve",
    "difficulty": 3,
    "summary": "Tomcat AJP 协议对请求属性校验不足，攻击者可通过 8009 端口读取 Web 应用目录内的任意文件，配合上传功能可升级为 RCE。",
    "tags": [
      "Tomcat",
      "AJP",
      "文件读取",
      "文件包含",
      "Java"
    ],
    "mitre": [
      "T1190",
      "T1005"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-jboss-201712149",
    "name": "JBoss 反序列化",
    "subtitle": "CVE-2017-12149 · HttpInvoker RCE",
    "category": "cve",
    "difficulty": 3,
    "summary": "JBoss AS 5.x/6.x 的 HttpInvoker ReadOnlyAccessFilter 直接反序列化客户端提交的数据且未做安全检查，可导致远程代码执行。",
    "tags": [
      "JBoss",
      "Java",
      "反序列化",
      "RCE"
    ],
    "mitre": [
      "T1190",
      "T1059"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-spring-20181273",
    "name": "Spring Data Commons SpEL 注入",
    "subtitle": "CVE-2018-1273 · 表达式注入 RCE",
    "category": "cve",
    "difficulty": 3,
    "summary": "Spring Data Commons 2.0.5 及之前版本在参数绑定过程中把用户输入当作 SpEL 求值，攻击者可注入表达式执行任意命令。",
    "tags": [
      "Spring Data",
      "SpEL",
      "RCE",
      "Java"
    ],
    "mitre": [
      "T1190",
      "T1059"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-struts2-s2048",
    "name": "Struts2 S2-048",
    "subtitle": "CVE-2017-9791 · Showcase OGNL 注入",
    "category": "cve",
    "difficulty": 3,
    "summary": "Struts2 2.3.x 的 Showcase 应用在处理消息字段时存在 OGNL 注入，攻击者可通过构造参数值执行任意命令。",
    "tags": [
      "Struts2",
      "OGNL",
      "RCE",
      "Java"
    ],
    "mitre": [
      "T1190",
      "T1059"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-ofbiz-202351467",
    "name": "Apache OFBiz 认证绕过 RCE",
    "subtitle": "CVE-2023-51467 · Groovy 表达式注入",
    "category": "cve",
    "difficulty": 4,
    "summary": "OFBiz 18.12.10 对 CVE-2023-49070 的修复不完整，ProgramExport 端点可被未授权访问，并通过 Groovy 表达式注入执行命令。",
    "tags": [
      "OFBiz",
      "认证绕过",
      "Groovy",
      "RCE"
    ],
    "mitre": [
      "T1190",
      "T1059"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-samba-20177494",
    "name": "SambaCry",
    "subtitle": "CVE-2017-7494 · SMB 共享库加载 RCE",
    "category": "network",
    "difficulty": 3,
    "summary": "Samba 4.6.3 的 is_known_pipename() 未校验管道路径，认证或匿名可写共享用户可上传恶意共享库，并诱导服务加载执行。",
    "tags": [
      "Samba",
      "SMB",
      "RCE",
      "共享"
    ],
    "mitre": [
      "T1210",
      "T1059"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-libssh-201810933",
    "name": "libssh 认证绕过",
    "subtitle": "CVE-2018-10933 · SSH 状态机缺陷",
    "category": "network",
    "difficulty": 3,
    "summary": "libssh 服务端状态机在收到 MSG_USERAUTH_SUCCESS 后即认定认证成功，攻击者无需任何口令即可建立会话。",
    "tags": [
      "libssh",
      "SSH",
      "认证绕过",
      "CVE"
    ],
    "mitre": [
      "T1078",
      "T1021"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-opensmtpd-20207247",
    "name": "OpenSMTPD 命令注入",
    "subtitle": "CVE-2020-7247 · 发件人地址注入",
    "category": "network",
    "difficulty": 3,
    "summary": "OpenSMTPD 6.6.1p1 对 MAIL FROM 地址校验不严，注入 shell 元字符可在邮件投递流程中执行任意命令。",
    "tags": [
      "OpenSMTPD",
      "SMTP",
      "命令注入",
      "RCE"
    ],
    "mitre": [
      "T1190",
      "T1059"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-saltstack-202011651",
    "name": "SaltStack 认证绕过",
    "subtitle": "CVE-2020-11651 · Salt Master RCE",
    "category": "network",
    "difficulty": 3,
    "summary": "Salt Master 的 ClearFuncs 未校验调用者身份，攻击者可调用 _prep_auth_info 等内部函数获取密钥，并进一步在 master 上执行命令。",
    "tags": [
      "SaltStack",
      "认证绕过",
      "RCE",
      "运维"
    ],
    "mitre": [
      "T1190",
      "T1059"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-bash-20146271",
    "name": "Shellshock",
    "subtitle": "CVE-2014-6271 · Bash 环境变量注入",
    "category": "network",
    "difficulty": 2,
    "summary": "Bash 在处理函数定义环境变量时未正确截断，攻击者可在 User-Agent 等 HTTP 头中注入命令，经 CGI 脚本触发执行。",
    "tags": [
      "Bash",
      "Shellshock",
      "CGI",
      "命令注入"
    ],
    "mitre": [
      "T1190",
      "T1059"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-xxl-job-unacc",
    "name": "XXL-JOB 执行器未授权",
    "subtitle": "执行器 REST API · 命令执行",
    "category": "cloud",
    "difficulty": 2,
    "summary": "XXL-JOB 执行器默认未配置认证，攻击者可通过 RESTful API 直接下发任务并在目标主机执行任意命令。",
    "tags": [
      "XXL-JOB",
      "未授权",
      "任务调度",
      "RCE"
    ],
    "mitre": [
      "T1190",
      "T1059"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-nacos-202129441",
    "name": "Nacos 认证绕过",
    "subtitle": "CVE-2021-29441 · User-Agent 绕过",
    "category": "cloud",
    "difficulty": 2,
    "summary": "Nacos 1.4.1 之前版本将 User-Agent 为 Nacos-Server 的请求视为内部调用并跳过鉴权，攻击者可借此创建管理员用户。",
    "tags": [
      "Nacos",
      "认证绕过",
      "服务发现",
      "云原生"
    ],
    "mitre": [
      "T1190",
      "T1078"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-minio-202328432",
    "name": "MinIO 环境变量泄露",
    "subtitle": "CVE-2023-28432 · 集群信息泄露",
    "category": "cloud",
    "difficulty": 2,
    "summary": "MinIO 集群部署模式下 /minio/bootstrap/v1/verify 未做鉴权，会返回全部环境变量，其中包含 root 账号与口令。",
    "tags": [
      "MinIO",
      "对象存储",
      "信息泄露",
      "云原生"
    ],
    "mitre": [
      "T1190",
      "T1552"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-gradio-20241561",
    "name": "Gradio 任意文件读取",
    "subtitle": "CVE-2024-1561 · component_server 滥用",
    "category": "ai",
    "difficulty": 2,
    "summary": "Gradio 4.13 之前版本的 component_server 接口可调用 Component 的任意方法，借 move_resource_to_block_cache 把服务器任意文件复制到缓存并下载。",
    "tags": [
      "Gradio",
      "AI",
      "任意文件读取",
      "未授权"
    ],
    "mitre": [
      "T1190",
      "T1005"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-langflow-20253248",
    "name": "Langflow 未授权 RCE",
    "subtitle": "CVE-2025-3248 · validate/code 代码执行",
    "category": "ai",
    "difficulty": 3,
    "summary": "Langflow 1.3.0 之前版本的 /api/v1/validate/code 使用 exec 校验用户代码，装饰器与默认参数在函数定义时即被执行，导致未授权代码执行。",
    "tags": [
      "Langflow",
      "AI Agent",
      "未授权",
      "RCE"
    ],
    "mitre": [
      "T1190",
      "T1059"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-superset-202327524",
    "name": "Apache Superset JWT 伪造",
    "subtitle": "CVE-2023-27524 · 默认密钥认证绕过",
    "category": "ai",
    "difficulty": 2,
    "summary": "Superset 2.0.1 使用硬编码默认 SECRET_KEY 签发会话 Cookie，攻击者可用已知密钥伪造任意用户（含管理员）的会话。",
    "tags": [
      "Superset",
      "JWT",
      "认证绕过",
      "数据平台"
    ],
    "mitre": [
      "T1190",
      "T1552",
      "T1078"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-polkit-20214034",
    "name": "PwnKit",
    "subtitle": "CVE-2021-4034 · pkexec 本地提权",
    "category": "binary",
    "difficulty": 2,
    "summary": "pkexec 未正确处理 argv 为空的场景，攻击者通过构造环境变量与参数诱导其执行任意代码，从普通用户提升到 root。",
    "tags": [
      "Polkit",
      "pkexec",
      "本地提权",
      "Linux"
    ],
    "mitre": [
      "T1068",
      "T1548"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-imagemagick-20163714",
    "name": "ImageTragick",
    "subtitle": "CVE-2016-3714 · 图片处理命令注入",
    "category": "misc",
    "difficulty": 3,
    "summary": "ImageMagick 6.9.3-9 之前版本在调用 delegate 时未过滤文件名中的 shell 元字符，特制 MVG/SVG 图片可触发命令执行。",
    "tags": [
      "ImageMagick",
      "命令注入",
      "文件处理",
      "RCE"
    ],
    "mitre": [
      "T1203",
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 3072,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-activemq-cve-2023-46604",
    "name": "Apache ActiveMQ OpenWire 协议反序列化命令执行漏洞（CVE-2023-46604）",
    "subtitle": "CVE-2023-46604",
    "category": "network",
    "difficulty": 3,
    "summary": "Apache ActiveMQ 是美国阿帕奇（Apache）软件基金会所研发的一套开源的消息中间件，它支持 Java 消息服务、集群、Spring Framework 等。",
    "tags": [
      "RCE",
      "Deserialization",
      "Message Queue"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-activemq-cve-2024-32114",
    "name": "Apache ActiveMQ Jolokia API 未授权访问漏洞（CVE-2024-32114）",
    "subtitle": "CVE-2024-32114",
    "category": "network",
    "difficulty": 3,
    "summary": "CVE-2024-32114 是 Apache ActiveMQ 6.x 在 6.1.2 版本之前存在的一个漏洞，其默认配置未对 API Web 上下文进行安全防护。Jolokia JMX REST API 和 Message REST API 分别位于 `/api/jolokia` 和 `/api/message`，均无需任何身份认证即可访问。未经认证的攻击者可以通过这些 API 与消息代理进行交互，包括管理消息、清空队列以及调用任意 MBean 操作。结合 CVE-2026-34197，可以在 ActiveMQ 6.0.0 至 6.1.1 版本上实现未授权远程代码执行。",
    "tags": [
      "Info Disclosure",
      "Message Queue"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-apache-cxf-cve-2024-28752",
    "name": "Apache CXF Aegis DataBinding 服务端请求伪造漏洞 (CVE-2024-28752)",
    "subtitle": "CVE-2024-28752",
    "category": "cve",
    "difficulty": 3,
    "summary": "Apache CXF 是一个开源的服务框架，帮助开发者使用 JAX-WS 和 JAX-RS 等前端编程 API 构建和开发服务。",
    "tags": [
      "SSRF"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-cacti-cve-2023-39361",
    "name": "Cacti graph_view.php SQL 注入导致远程代码执行漏洞（CVE-2023-39361/CVE-2024-31459）",
    "subtitle": "CVE-2023-39361 · CVE-2024-31459",
    "category": "web",
    "difficulty": 3,
    "summary": "Cacti 是一个全面的网络图形化解决方案，旨在利用 RRDTool 的数据存储和图形功能，为网络管理员提供直观的界面来监控和分析网络性能数据。",
    "tags": [
      "SQL Injection",
      "RCE"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-confluence-cve-2023-22527",
    "name": "Confluence OGNL 表达式注入命令执行漏洞（CVE-2023-22527）",
    "subtitle": "CVE-2023-22527",
    "category": "cve",
    "difficulty": 3,
    "summary": "Atlassian Confluence 是企业广泛使用的 wiki 系统。",
    "tags": [
      "RCE",
      "Expression Injection"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-craftcms-cve-2023-41892",
    "name": "CraftCMS 未授权远程代码执行漏洞（CVE-2023-41892）",
    "subtitle": "CVE-2023-41892",
    "category": "web",
    "difficulty": 3,
    "summary": "Craft CMS 是一个灵活、用户友好的内容管理系统，用于在 Web 上创建自定义的数字体验。它为用户提供了一个后端界面来实现网站并配置 CMS。",
    "tags": [
      "RCE",
      "CMS"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-craftcms-cve-2024-56145",
    "name": "CraftCMS `register_argc_argv` 导致远程代码执行漏洞（CVE-2024-56145）",
    "subtitle": "CVE-2024-56145",
    "category": "web",
    "difficulty": 3,
    "summary": "CraftCMS 是一个基于 PHP 的内容管理系统，用于构建网站和应用程序。",
    "tags": [
      "RCE",
      "CMS"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-erlang-cve-2025-32433",
    "name": "Erlang/OTP SSH 未授权远程代码执行漏洞（CVE-2025-32433）",
    "subtitle": "CVE-2025-32433",
    "category": "network",
    "difficulty": 3,
    "summary": "Erlang/OTP SSH 是 Erlang/OTP 平台自带的 SSH 服务器组件。",
    "tags": [
      "RCE"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-geoserver-cve-2023-25157",
    "name": "GeoServer OGC Filter SQL 注入漏洞（CVE-2023-25157）",
    "subtitle": "CVE-2023-25157",
    "category": "cve",
    "difficulty": 3,
    "summary": "GeoServer 是 OpenGIS Web 服务器规范的 J2EE 实现，利用 GeoServer 可以方便的发布地图数据，允许用户对特征数据进行更新、删除、插入操作。",
    "tags": [
      "SQL Injection"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-geoserver-cve-2024-36401",
    "name": "GeoServer 属性名表达式前台代码执行漏洞（CVE-2024-36401）",
    "subtitle": "CVE-2024-36401",
    "category": "cve",
    "difficulty": 3,
    "summary": "GeoServer 是 OpenGIS Web 服务器规范的 J2EE 实现，利用 GeoServer 可以方便的发布地图数据，允许用户对特征数据进行更新、删除、插入操作。",
    "tags": [
      "RCE",
      "Expression Injection"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-gradio-cve-2023-51449",
    "name": "Gradio 目录穿越漏洞（CVE-2023-51449）",
    "subtitle": "CVE-2023-51449",
    "category": "ai",
    "difficulty": 3,
    "summary": "Gradio 是一个 Python 库，允许用户无需编写前端代码即可为机器学习模型快速构建可视化 Web 界面。",
    "tags": [
      "Path Traversal",
      "LLM"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-grafana-cve-2024-9264",
    "name": "Grafana SQL Expressions 远程代码执行漏洞（CVE-2024-9264）",
    "subtitle": "CVE-2024-9264",
    "category": "cve",
    "difficulty": 3,
    "summary": "CVE-2024-9264 是 Grafana 实验性 SQL Expressions 功能中的一个严重漏洞，影响版本为 11.0.0 至 11.0.5、11.1.0 至 11.1.6 以及 11.2.0 至 11.2.1。该功能允许使用 SQL 对数据源查询结果进行后处理，底层通过 DuckDB 引擎执行 SQL 查询。由于输入校验不充分，拥有 Viewer 及以上权限的攻击者可以注入任意 DuckDB SQL 语句，实现任意文件读取和远程代码执行。虽然该功能被标记为实验性，但由于 feature flag 实现存在缺陷，该功能在 API 层面被默认启用，扩大了攻击面。漏洞利用的前提条件是 Grafana 进程的系统 PATH 中存在 DuckDB ",
    "tags": [
      "RCE",
      "SQL Injection"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-hertzbeat-cve-2024-42323",
    "name": "Apache HertzBeat SnakeYaml 反序列化远程代码执行漏洞（CVE-2024-42323）",
    "subtitle": "CVE-2024-42323",
    "category": "cve",
    "difficulty": 3,
    "summary": "Apache HertzBeat 是一款开源的实时监控告警工具，支持对操作系统、中间件、数据库等多种对象进行监控，并提供 Web 界面进行管理。",
    "tags": [
      "RCE",
      "Deserialization"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-hugegraph-cve-2024-27348",
    "name": "Apache HugeGraph 远程代码执行漏洞（CVE-2024-27348）",
    "subtitle": "CVE-2024-27348",
    "category": "cve",
    "difficulty": 3,
    "summary": "Apache HugeGraph 是一款快速、高度可扩展的图数据库。它提供了完整的图数据库功能、出色的性能和企业级的可靠性。",
    "tags": [
      "RCE"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-jenkins-cve-2024-23897",
    "name": "Jenkins CLI 接口任意文件读取漏洞（CVE-2024-23897）",
    "subtitle": "CVE-2024-23897",
    "category": "cloud",
    "difficulty": 3,
    "summary": "Jenkins 是一个开源的自动化服务器。",
    "tags": [
      "Path Traversal"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-kafka-cve-2023-25194",
    "name": "Apache Kafka Clients JNDI 注入漏洞 (CVE-2023-25194)",
    "subtitle": "CVE-2023-25194",
    "category": "network",
    "difficulty": 3,
    "summary": "Apache Kafka 是一个开源分布式消息队列，Kafka clients 是相对应的 Java 客户端。",
    "tags": [
      "RCE",
      "Message Queue"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-metabase-cve-2023-38646",
    "name": "Metabase 未授权 JDBC 远程代码执行漏洞（CVE-2023-38646）",
    "subtitle": "CVE-2023-38646",
    "category": "cve",
    "difficulty": 3,
    "summary": "Metabase 是一个开源的数据分析平台。在其 0.46.6 版本及以前，存在一处远程代码执行漏洞，未授权的用户可以使用 JDBC 注入在服务器上执行任意代码。",
    "tags": [
      "RCE"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-next-js-cve-2025-29927",
    "name": "Next.js 中间件鉴权绕过漏洞 (CVE-2025-29927)",
    "subtitle": "CVE-2025-29927",
    "category": "web",
    "difficulty": 3,
    "summary": "Next.js 是一个基于 React 的流行 Web 应用框架，提供服务器端渲染、静态网站生成和集成路由系统等功能。当使用中间件进行身份验证和授权时，Next.js 14.2.25 和 15.2.3 之前的版本存在授权绕过漏洞。",
    "tags": [
      "Auth Bypass",
      "Framework"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-nexus-cve-2024-4956",
    "name": "Nexus Repository Manager 3 未授权目录穿越漏洞（CVE-2024-4956）",
    "subtitle": "CVE-2024-4956",
    "category": "cve",
    "difficulty": 3,
    "summary": "Nexus Repository Manager 3 是一款软件仓库，可以用来存储和分发 Maven、NuGET 等软件源仓库。",
    "tags": [
      "Path Traversal"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-openfire-cve-2023-32315",
    "name": "Openfire 管理后台认证绕过漏洞（CVE-2023-32315）",
    "subtitle": "CVE-2023-32315",
    "category": "cve",
    "difficulty": 3,
    "summary": "Openfire 是根据开放源 Apache 许可获得许可的实时协作（RTC）服务器。",
    "tags": [
      "Auth Bypass"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-owncloud-cve-2023-49103",
    "name": "ownCloud graphapi 信息泄露漏洞（CVE-2023-49103）",
    "subtitle": "CVE-2023-49103",
    "category": "web",
    "difficulty": 3,
    "summary": "graphapi 是 ownCloud Server 自 10.6 版本起内置的一个 Microsoft Graph API 扩展应用，用于提供用户和组信息接口，以支持 ownCloud Server 10 与 ownCloud Infinite Scale 之间的桥接部署。CVE-2023-49103 是该应用中的一个严重信息泄露漏洞，影响 graphapi 0.2.0 至 0.3.0 版本。由于 graphapi 随 ownCloud Server 预装，根据官方公告，所有低于 10.13.3 版本的 ownCloud Server 实例均受影响。graphapi 的修复版本为 0.3.1，官方建议升级到至少 10.13.3 版本。",
    "tags": [
      "Info Disclosure"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-pdfjs-cve-2024-4367",
    "name": "PDF.js 任意 JavaScript 代码执行（CVE-2024-4367）",
    "subtitle": "CVE-2024-4367",
    "category": "web",
    "difficulty": 3,
    "summary": "PDF.js 是 Mozilla 推出的一款开源 PDF 文件阅读器。",
    "tags": [
      "RCE"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-pgadmin-cve-2023-5002",
    "name": "pgAdmin <= 7.6 后台远程命令执行漏洞（CVE-2023-5002）",
    "subtitle": "CVE-2023-5002",
    "category": "cve",
    "difficulty": 3,
    "summary": "pgAdmin 是一个著名的 PostgreSQL 数据库管理平台。",
    "tags": [
      "RCE"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-python-cve-2024-23334",
    "name": "aiohttp 目录遍历漏洞（CVE-2024-23334）",
    "subtitle": "CVE-2024-23334",
    "category": "web",
    "difficulty": 3,
    "summary": "aiohttp 是一个基于 asyncio 和 Python 的异步 HTTP 客户端/服务器框架。",
    "tags": [
      "Path Traversal"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-rocketmq-cve-2023-33246",
    "name": "Apache RocketMQ Broker 远程命令执行漏洞（CVE-2023-33246）",
    "subtitle": "CVE-2023-33246",
    "category": "network",
    "difficulty": 3,
    "summary": "Apache RocketMQ 是一个分布式消息平台。",
    "tags": [
      "RCE",
      "Message Queue"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-spring-cve-2022-22978",
    "name": "Spring Security RegexRequestMatcher 认证绕过漏洞（CVE-2022-22978）",
    "subtitle": "CVE-2022-22978",
    "category": "cve",
    "difficulty": 3,
    "summary": "Spring Security 用于在 Spring 框架中提供安全认证功能。在 Spring Security 5.5.6、5.6.3 及更早的不受支持版本中，使用带有 `.` 的正则表达式的 RegexRequestMatcher 的应用程序可能存在认证绕过漏洞。",
    "tags": [
      "Auth Bypass",
      "Framework"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-teamcity-cve-2024-27198",
    "name": "JetBrains TeamCity 认证绕过漏洞（CVE-2024-27198）",
    "subtitle": "CVE-2024-27198",
    "category": "cloud",
    "difficulty": 3,
    "summary": "CVE-2024-27198 是一个影响 JetBrains TeamCity On-Premises 2023.11.4 之前所有版本的严重认证绕过漏洞。该漏洞存在于 `BaseController` 类中，其 `updateViewIfRequestHasJspParameter()` 方法会读取 `jsp` 查询参数并将其设置为请求转发的视图名称。攻击者可以请求任意不存在的 URL（触发 404 响应），并在 `jsp` 参数中指向一个受保护的 REST API 端点，同时添加 `;.jsp` 后缀。分号在 Servlet 规范中作为路径参数分隔符——应用服务器在解析路径时会去除分号后的所有内容，但原始字符串仍然能通过 `.jsp` 后缀验证检查",
    "tags": [
      "Auth Bypass",
      "RCE"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-tomcat-cve-2025-24813",
    "name": "Tomcat 远程代码执行漏洞（CVE-2025-24813）",
    "subtitle": "CVE-2025-24813",
    "category": "cve",
    "difficulty": 3,
    "summary": "Apache Tomcat 是一个广泛使用的开源 Java Servlet、JavaServer Pages、Java Expression Language 和 WebSocket 技术的实现。",
    "tags": [
      "RCE",
      "Deserialization",
      "Webserver"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-vite-cve-2025-30208",
    "name": "Vite 开发服务器任意文件读取漏洞绕过（CVE-2025-30208）",
    "subtitle": "CVE-2025-30208",
    "category": "web",
    "difficulty": 3,
    "summary": "Vite 是一个现代前端构建工具，为 Web 项目提供更快、更精简的开发体验。它主要由两部分组成：具有热模块替换（HMR）功能的开发服务器，以及使用 Rollup 打包代码的构建命令。",
    "tags": [
      "Path Traversal"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-weblogic-cve-2023-21839",
    "name": "WebLogic 未授权远程代码执行漏洞 (CVE-2023-21839)",
    "subtitle": "CVE-2023-21839",
    "category": "cve",
    "difficulty": 3,
    "summary": "Oracle WebLogic Server 是业界广泛使用的 Java EE 企业级应用服务器。",
    "tags": [
      "RCE",
      "Webserver"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-adminer-cve-2021-21311",
    "name": "Adminer ElasticSearch 和 ClickHouse 错误页面 SSRF 漏洞（CVE-2021-21311）",
    "subtitle": "CVE-2021-21311",
    "category": "web",
    "difficulty": 3,
    "summary": "Adminer 是一个 PHP 编写的开源数据库管理工具，支持 MySQL、MariaDB、PostgreSQL、SQLite、MS SQL、Oracle、Elasticsearch、MongoDB 等数据库。",
    "tags": [
      "SSRF",
      "Database"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-airflow-cve-2020-17526",
    "name": "Apache Airflow 默认密钥导致的权限绕过（CVE-2020-17526）",
    "subtitle": "CVE-2020-17526",
    "category": "cloud",
    "difficulty": 3,
    "summary": "Apache Airflow 是一款开源的，分布式任务调度框架。默认情况下，Apache Airflow 无需用户认证，但管理员也可以通过指定 `webserver.authenticate=True` 来开启认证。",
    "tags": [
      "Auth Bypass"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-apisix-cve-2021-45232",
    "name": "Apache APISIX Dashboard API 权限绕过导致 RCE（CVE-2021-45232）",
    "subtitle": "CVE-2021-45232",
    "category": "cloud",
    "difficulty": 3,
    "summary": "Apache APISIX 是一个动态、实时、高性能 API 网关，而 Apache APISIX Dashboard 是一个配套的前端面板。",
    "tags": [
      "RCE",
      "Auth Bypass",
      "Webserver"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-couchdb-cve-2022-24706",
    "name": "CouchDB Erlang 分布式协议代码执行 (CVE-2022-24706)",
    "subtitle": "CVE-2022-24706",
    "category": "network",
    "difficulty": 3,
    "summary": "Apache CouchDB 是一个 Erlang 开发的 NoSQL 数据库。",
    "tags": [
      "RCE",
      "Database"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-flask-ssti",
    "name": "Flask（Jinja2）服务端模板注入漏洞",
    "subtitle": "SSTI · RCE",
    "category": "web",
    "difficulty": 3,
    "summary": "Flask 是一个流行的 Python Web 框架，使用 Jinja2 作为其模板引擎。当用户输入未经适当过滤就直接在 Jinja2 模板中渲染时，可能会导致服务端模板注入（SSTI）漏洞，进而可能导致远程代码执行。",
    "tags": [
      "SSTI",
      "RCE",
      "Framework"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-h2database-cve-2021-42392",
    "name": "H2 Database Web 控制台未授权 JNDI 注入 RCE 漏洞（CVE-2021-42392）",
    "subtitle": "CVE-2021-42392",
    "category": "network",
    "difficulty": 3,
    "summary": "H2 Database 是一个快速、开源的基于 Java 的关系型数据库管理系统（RDBMS），可用于嵌入式（集成在 Java 应用中）和客户端 - 服务器模式。",
    "tags": [
      "Database",
      "RCE"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-hadoop-unauthorized-yarn",
    "name": "Hadoop YARN ResourceManager 未授权访问漏洞",
    "subtitle": "RCE · Auth Bypass",
    "category": "cloud",
    "difficulty": 3,
    "summary": "Hadoop YARN（Yet Another Resource Negotiator）是 Apache Hadoop 的集群资源管理系统。YARN ResourceManager 中存在一个未授权访问漏洞，由于缺少访问控制，未经授权的用户可以在集群上提交并执行任意应用程序。",
    "tags": [
      "RCE",
      "Auth Bypass"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-httpd-cve-2021-40438",
    "name": "Apache HTTP Server 2.4.48 mod_proxy SSRF 漏洞（CVE-2021-40438）",
    "subtitle": "CVE-2021-40438",
    "category": "cve",
    "difficulty": 3,
    "summary": "Apache HTTP Server 是 Apache 基金会开源的一款流行的 HTTP 服务器。在其 2.4.48 及以前的版本中，mod_proxy 模块存在一处逻辑错误导致攻击者可以控制反向代理服务器的地址，进而导致 SSRF 漏洞。",
    "tags": [
      "SSRF",
      "Webserver"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-influxdb-cve-2019-20933",
    "name": "InfluxDB JWT 认证绕过漏洞（CVE-2019-20933）",
    "subtitle": "CVE-2019-20933",
    "category": "network",
    "difficulty": 3,
    "summary": "InfluxDB 是一款著名的时序数据库，其使用 jwt 作为鉴权方式。",
    "tags": [
      "Auth Bypass",
      "Hard Coding"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-jupyter-notebook-rce",
    "name": "Jupyter Notebook 未授权访问漏洞",
    "subtitle": "Auth Bypass",
    "category": "ai",
    "difficulty": 3,
    "summary": "Jupyter Notebook（此前被称为 IPython notebook）是一个交互式笔记本，支持运行 40 多种编程语言。",
    "tags": [
      "Auth Bypass"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-php-php-xxe",
    "name": "PHP XML 外部实体注入漏洞（XXE）",
    "subtitle": "XXE",
    "category": "web",
    "difficulty": 3,
    "summary": "XML 外部实体注入（XXE）是一种发生在应用程序解析 XML 输入时的安全漏洞。当 XML 解析器配置不当，处理包含对外部实体引用的 XML 输入时，可能导致敏感信息泄露、拒绝服务、服务器端请求伪造、端口扫描等多种攻击。",
    "tags": [
      "XXE"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-rsync-common",
    "name": "Rsync 未授权访问漏洞",
    "subtitle": "Auth Bypass",
    "category": "network",
    "difficulty": 3,
    "summary": "Rsync 是 Linux 下一款数据备份工具，支持通过 rsync 协议、ssh 协议进行远程文件传输。其中 rsync 协议默认监听 873 端口，如果目标开启了 rsync 服务，并且没有配置 ACL 或访问密码，我们将可以读写目标服务器文件。",
    "tags": [
      "Auth Bypass"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-solr-cve-2017-12629-xxe",
    "name": "Apache Solr XML 外部实体注入漏洞（CVE-2017-12629）",
    "subtitle": "CVE-2017-12629",
    "category": "cve",
    "difficulty": 3,
    "summary": "Apache Solr 是一个开源的搜索服务器。它使用 Java 语言开发，主要基于 HTTP 和 Apache Lucene 实现。在 7.1.0 版本之前，发现了两个漏洞：XML 外部实体注入（XXE）和远程命令执行（RCE），这两个漏洞的编号均为 CVE-2017-12629。这两个漏洞可以连接成利用链。",
    "tags": [
      "XXE"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-spark-unacc",
    "name": "Apache Spark 未授权访问导致远程代码执行",
    "subtitle": "RCE · Auth Bypass",
    "category": "cloud",
    "difficulty": 3,
    "summary": "Apache Spark 是一款集群计算系统，其支持用户向管理节点提交应用，并分发给集群执行。如果管理节点未启动 ACL（访问控制），我们将可以在集群中执行任意代码。",
    "tags": [
      "RCE",
      "Auth Bypass"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-django-cve-2022-34265",
    "name": "Django Trunc(kind) 和 Extract(lookup_name) 函数 SQL 注入漏洞（CVE-2022-34265）",
    "subtitle": "CVE-2022-34265",
    "category": "web",
    "difficulty": 3,
    "summary": "Django 是一个高级的 Python Web 框架，支持快速开发和简洁实用的设计。",
    "tags": [
      "SQL Injection",
      "Framework"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-couchdb-cve-2017-12635",
    "name": "Couchdb 垂直权限绕过漏洞（CVE-2017-12635）",
    "subtitle": "CVE-2017-12635",
    "category": "network",
    "difficulty": 3,
    "summary": "Apache CouchDB 是一个开源数据库，专注于易用性和成为\"完全拥抱 web 的数据库\"。它是一个使用 JSON 作为存储格式，JavaScript 作为查询语言，MapReduce 和 HTTP 作为 API 的 NoSQL 数据库。应用广泛，如 BBC 用在其动态内容展示平台，Credit Suisse 用在其内部的商品部门的市场框架，Meebo，用在其社交平台（web 和应用程序）。",
    "tags": [
      "Auth Bypass",
      "Database"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  },
  {
    "id": "vulhub-dataease-cve-2025-49001",
    "name": "DataEase JWT 认证绕过漏洞（CVE-2025-49001）",
    "subtitle": "CVE-2025-49001",
    "category": "cve",
    "difficulty": 3,
    "summary": "DataEase 是一款广泛使用的开源数据可视化分析平台，常用于搭建 BI 仪表盘。",
    "tags": [
      "Auth Bypass"
    ],
    "mitre": [
      "T1190"
    ],
    "ports": [
      8080
    ],
    "ram_mb": 4096,
    "supports_awd_patch": true,
    "source": "vulhub"
  }
];
