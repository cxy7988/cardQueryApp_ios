> Legacy guide: water/electricity queries now use authenticated server tasks. See [README](README.md) for the current login, room binding and query flow.

iPhone Packet Capture Tutorial
---

## ✅ Table of Contents

- [iPhone Packet Capture Tutorial](#iphone-packet-capture-tutorial)
- [✅ Table of Contents](#-table-of-contents)
- [🔧 Prerequisites](#-prerequisites)
- [🛠 Computer Configuration](#-computer-configuration)
  - [1. Download and Install](#1-download-and-install)
  - [2. Enable HTTPS Capture and Certificate Trust](#2-enable-https-capture-and-certificate-trust)
- [📲 iPhone Configuration](#-iphone-configuration)
- [🚀 Start Packet Capture](#-start-packet-capture)
- [🧩 Common Issues Troubleshooting](#-common-issues-troubleshooting)

---

## 🔧 Prerequisites

* A computer with **Fiddler Everywhere** installed (supports Windows / macOS / Linux)
* An **iPhone** connected to the same Wi-Fi network as the computer
* **Turn off VPN, turn off VPN, turn off VPN** - this is important and bears repeating


## 🛠 Computer Configuration

### 1. Download and Install

Official website: [https://www.telerik.com/fiddler-everywhere](https://www.telerik.com/fiddler-everywhere)

### 2. Enable HTTPS Capture and Certificate Trust

After opening Fiddler Everywhere, click in sequence:

```
Settings (gear icon in top right) → HTTPS → 
✅ Capture HTTPS traffic  
✅ Decrypt HTTPS traffic  
```

Fiddler will prompt to install the certificate, click "Trust and Install". This step only completes the certificate configuration for the "computer side", then go to:

```
Settings → Connections → ✅ Allow remote devices to connect
```

⚠️ **Note down your computer's IP address**:

* macOS/Linux: Enter `ifconfig` or `ip addr` in terminal
* Windows: Enter `ipconfig` in command prompt
  Example: `192.168.1.88`

Default listening port: **8866** (can be modified in Settings ▸ Connections)


## 📲 iPhone Configuration

1. Open iPhone "Settings" → Wi-Fi → Current network → Tap `ⓘ`
2. Scroll to bottom, set **HTTP Proxy** to "Manual"
3. Configure as follows: Your computer IP (e.g., `192.168.1.88`) + `8866` (or your set port)
4. Access through browser
5. Open iPhone Safari browser, visit: http://<your computer IP>:8866
6. You'll see a certificate download page, click **Download Certificate**
7. iOS popup shows "Configuration Profile", tap **Allow → Close**


Install Configuration Profile

1. Settings → Downloaded Profile
2. Tap Install → Enter passcode → Install → Done

Trust Root Certificate

1. Go to Settings → General → About → **Certificate Trust Settings**
2. Enable the corresponding **Fiddler Root Certificate** trust switch


## 🚀 Start Packet Capture

1. Return to Fiddler Everywhere, click "Live Traffic" in top left → Ensure it's green (listening)
2. On iPhone, open WeChat - Wenzhou-Kean University Campus Card official account, query balance
3. In Fiddler Everywhere's list, find the entry with URL "https://webapp.xiaofubao.com/card/getCardMoney"
4. Copy the cookies part after "shiroJID=" to our APP's settings


## 🧩 Common Issues Troubleshooting

| Issue                                    | Solution                                  |
| ---------------------------------------- | ---------------------------------------- |
| Phone webpage shows "Invalid Certificate" | Check if "Trust Root Certificate" switch is enabled in iOS |
| Cannot access [http://IP:8866](http://IP:8866) | Check if Fiddler is running, computer firewall blocking |
| HTTPS cannot be decrypted                | Ensure "Decrypt HTTPS traffic" is enabled and certificate is trusted on phone |
| Phone packet capture shows no response   | Confirm Wi-Fi network consistency, proxy settings correct, no VPN interference | 