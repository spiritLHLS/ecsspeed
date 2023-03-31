# ecsspeed

## 说明

### 对应 [speedtest.net](https://www.speedtest.net/) 的自动更新测速ID的测速脚本

```
bash <(wget -qO- bash.spiritlhl.net/ecs-net)
```

或

```
bash <(wget -qO- --no-check-certificate https://github.com/spiritLHLS/ecsspeed/raw/main/script/ecsspeed-net.sh)
```

涵盖中国三大运营商、香港、台湾的测速节点，默认三网测速每个运营商选择本机ping值最低的两个节点测速，节点大概每7天自动更新一次。

## 功能

- [x] 自动抓取 [speedtest.cn](https://www.speedtest.cn/) 节点信息结合已有信息去重并更新列表数据
- [x] 自动抓取 [speedtest.net](https://www.speedtest.net/) 节点信息结合已有信息去重并更新列表数据
- [x] 对应 [speedtest.net](https://www.speedtest.net/) 的自动更新测速ID的测速脚本
- [ ] 对应 [speedtest.cn](https://www.speedtest.cn/) 的自动更新测速ID的测速脚本

## .cn数据

北京时间每日7点半更新，感谢测速站点提供的服务

这里只展示CN地区的节点信息

闭源收录服务器数量(实时)：2392

### 分类数据

静态页面：https://spiritlhls.github.io/ecsspeed/

#### 粗分类

移动数据 - [mobile.csv](mobile.csv)

电信数据 - [telecom.csv](telecom.csv)

联通数据 - [unicom.csv](unicom.csv)

香港数据 - [HK.csv](HK.csv)

台湾数据 - [TW.csv](TW.csv)

中国数据 - [CN.csv](CN.csv)

## .net数据

仓库：https://github.com/spiritLHLS/speedtest.net-CN-ID

### 交流

admin@spiritlhl.net

# 免责声明

* 本仓库仅供学习
* 不可用于商业以及非法目的，使用本仓库代码产生的一切后果, 作者不承担任何责任.
* 本仓库链接仅网络收集，侵权告知必删，使用相关链接产生的一切后果，作者不承担任何责任。

## Special statement:

Any unlocking and decryption analysis scripts involved in the Script project released by this warehouse are only used for testing, learning and research, and are forbidden to be used for commercial purposes. Their legality, accuracy, completeness and effectiveness cannot be guaranteed. Please make your own judgment based on the situation. .

All resource files in this project are forbidden to be reproduced or published in any form by any official account or self-media.

This warehouse is not responsible for any script problems, including but not limited to any loss or damage caused by any script errors.

Any user who indirectly uses the script, including but not limited to establishing a VPS or disseminating it when certain actions violate national/regional laws or related regulations, this warehouse is not responsible for any privacy leakage or other consequences caused by this.

Do not use any content of the Script project for commercial or illegal purposes, otherwise you will be responsible for the consequences.

If any unit or individual believes that the script of the project may be suspected of infringing on their rights, they should promptly notify and provide proof of identity and ownership. We will delete the relevant script after receiving the certification document.

Anyone who views this item in any way or directly or indirectly uses any script of the Script item should read this statement carefully. This warehouse reserves the right to change or supplement this disclaimer at any time. Once you have used and copied any relevant scripts or rules of the Script project, you are deemed to have accepted this disclaimer.


## Stargazers over time

[![Stargazers over time](https://starchart.cc/spiritLHLS/speedtest-crawler.svg)](https://github.com/spiritLHLS/speedtest-crawler)
