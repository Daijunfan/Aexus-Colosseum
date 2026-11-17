# 数字取证工作站

## 工具
- `vol` / `volatility3`：内存取证（进程、网络、注册表、时间线）
- `fls`, `icat`, `mmls`, `tsk_recover`：磁盘取证（SleuthKit）
- `tshark`：网络流量分析
- `binwalk`, `foremost`, `scalpel`, `exiftool`, `yara`：文件雕刻与特征分析

## 建议练习
1. 取一个公开内存镜像（例如 Volatility 官方样例），运行 `vol -f <镜像> windows.pslist`。
2. 用 `fls -r -m / -o <偏移> image.dd > bodyfile` 导出文件系统时间线。
3. 用 `tshark -r capture.pcap -Y "http.request" -T fields -e http.host -e http.request.uri` 还原 C2 会话。
4. 针对样本编写一条 YARA 规则并在 `/cases` 内测试。
