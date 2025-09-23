iPhone 抓包教程
---

## ✅ 目录

- [iPhone 抓包教程](#iphone-抓包教程)
- [✅ 目录](#-目录)
- [🔧 准备工作](#-准备工作)
- [🛠 电脑端配置](#-电脑端配置)
  - [1. 下载并安装](#1-下载并安装)
  - [2. 启用 HTTPS 抓包和证书信任](#2-启用-https-抓包和证书信任)
- [📲 手机端配置](#-手机端配置)
- [🚀 开始抓包](#-开始抓包)
- [🧩 常见问题排查](#-常见问题排查)

---

## 🔧 准备工作

* 一台装有 **Fiddler Everywhere** 的电脑（支持 Windows / macOS / Linux）
* 一部 **iPhone**，需与电脑连接同一局域网 Wi‑Fi
* **关闭VPN，关闭VPN，关闭VPN**，重要的事情说三次


## 🛠 电脑端配置

### 1. 下载并安装

官网地址：[https://www.telerik.com/fiddler-everywhere](https://www.telerik.com/fiddler-everywhere)

### 2. 启用 HTTPS 抓包和证书信任

打开 Fiddler Everywhere 后，依次点击：

```
Settings（右上角齿轮） → HTTPS → 
✅ Capture HTTPS traffic  
✅ Decrypt HTTPS traffic  
```

Fiddler 会提示安装证书，点击「信任并安装」。此步骤仅完成「电脑端」的证书配置，然后前往：

```
Settings → Connections → ✅ Allow remote devices to connect
```

⚠️ **记下你的电脑 IP 地址**：

* macOS/Linux：在终端输入 `ifconfig` 或 `ip addr`
* Windows：命令提示符输入 `ipconfig`
  例如：`192.168.1.88`

默认监听端口：**8866**（可以在 Settings ▸ Connections 中修改）


## 📲 手机端配置

1. 打开手机「设置」→ WLAN → 当前网络 → 点击 `ⓘ`
2. 滑到底部，**HTTP 代理** 设置为「手动」
3. 配置如下： 你的电脑 IP（如 `192.168.1.88`）+  `8866`（或你设置的端口）
4. 通过浏览器访问
5. 打开 iPhone Safari 浏览器，访问：http://<你的电脑 IP>:8866
6. 会看到一个证书下载页面，点击 **Download Certificate**
7. iOS 弹窗提示 “配置描述文件”，点击 **允许 → 关闭**


安装描述文件

1. 设置 → 已下载描述文件
2. 点击安装 → 输入锁屏密码 → 安装 → 完成

信任根证书

1. 前往 设置 → 通用 → 关于本机 → **证书信任设置**
2. 启用对应的 **Fiddler Root Certificate** 信任开关


## 🚀 开始抓包

1. 回到 Fiddler Everywhere，点击左上角「Live Traffic」→ 确保是绿色状态（正在监听）
2. 在 iPhone 上打开微信-温州肯恩大学校园卡公众号，查询余额
3. 在Fiddler Everywhere的列表中找到URL为 "https://webapp.xiaofubao.com/card/getCardMoney" 的选项
4. 复制 "shiroJID=" 后面的cookies部分到我们APP的设置之中


## 🧩 常见问题排查

| 问题                                    | 解决方案                                  |
| ------------------------------------- | ------------------------------------- |
| 手机网页提示“证书无效”                          | 检查是否在 iOS 中「信任根证书」开关已打开               |
| 无法访问 [http://IP:8866](http://IP:8866) | 检查 Fiddler 是否在运行、电脑防火墙是否拦截            |
| HTTPS 无法解密                            | 确保启用了「Decrypt HTTPS traffic」，并手机端信任证书 |
| 手机抓包无反应                               | 确认 Wi‑Fi 网络一致、代理设置正确、没有 VPN 干扰        |

