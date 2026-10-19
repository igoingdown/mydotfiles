## Introduction
This repository is used to manage all my dot configuration files, it includes:

>* Vim
>* Tmux <= V2.8
>* Zsh
>* Bash
>* NeoVim

## 慢查询可视化日报

`scripts/slowquery_daily.py` 从 DAS 数字直方图生成昨日、前天、上周同日的分小时对照和近七日趋势。实线表示当前窗口，虚线表示历史窗口，同时生成中文结论、PNG、CSV 和飞书文档。MySQL 累计耗时与 PostgreSQL 全量次数分开呈现；PostgreSQL 业务耗时尚未核实，始终显示待核。

依赖 Python 3.10+、matplotlib（含 Pillow）、中文字体、已有认证的 Aliyun CLI 和 lark-cli，以及飞书代码块换行检查脚本。不会读取或复制任何 API key；仅调用数字统计接口。统计失败、覆盖不全或独立小时核验失败时保留缺失，不能视为零或正常。当前节点集合用于所有比较窗口，不覆盖已退役节点，数据口径不能直接拼接旧的 SQL 分类报表。

复制 `scripts/slowquery-report.config.example.json` 到仓库外的私有目录，填入执行路径、统计实例、区域和已验证的本人身份（不含凭证），权限设为 600。状态目录保持私有、持久化；运行锁、24 小时历史缓存、冻结报告、文档与逐条发送状态均在这里。配置、实际数据、群与个人标识均不得提交此公开仓库。

使用 `python3 scripts/slowquery_daily.py --config /absolute/private/config.json --dry-run` 先本地取数和画图。去掉 `--dry-run` 后默认生成文档并发送到固定的本人；`--no-send` 只发布文档。`--mode halfday` 使用最近已闭合的北京时间 10/22 点十二小时窗口，默认只建文档，另加 `--send-self` 才发送。可指定 `--day YYYY-MM-DD` 或十二小时模式的 `--window-end ISO时间`；仅支持已闭合窗口。

`scripts/slowquery_install.py` 可用 `--config`、`--state-dir`、`--release-dir`、`--daily-path`、`--domain-path` 安装不可变源码副本并替换已有入口，保留既有 cron 时刻和领域脚本被其他任务导入的函数。参数都必须是绝对路径。安装失败会停止旧的不安全取数入口，不会自动恢复旧逻辑；恢复时安装已审查的安全版本，保留同一状态目录，不能清理发送状态。发布后同一报告包永久冻结，重跑只恢复原包；已发送消息不会重发，未知发送结果仅在原始去重有效期内重试，超过窗口则需人工核对。

本地验证：`python3 -m unittest discover -s scripts/slowquery_report -t . -q`。测试使用合成数据，并通过安装后的入口在精简 cron 环境执行日/十二小时完整本地链路；线上数据和飞书实际投递需部署后另行核验。

## Tutorials

* [程序员内功系列--序篇](https://xiaozhou.net/learn-the-command-line-preface-2017-05-12.html)
* [程序员内功系列--iTerm与Zsh篇](https://xiaozhou.net/learn-the-command-line-iterm-and-zsh-2017-06-23.html)
* [程序员内功系列--Tmux篇](https://xiaozhou.net/learn-the-command-line-tmux-2018-04-27.html)
* [程序员内功系列–-Vim篇](https://xiaozhou.net/learn-the-command-line-preface-2017-05-12.html)  
* [程序员内功系列–-常用命令行工具篇](https://xiaozhou.net/learn-the-command-line-tools-md-2018-10-11.html)  


