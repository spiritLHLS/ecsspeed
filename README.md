# ecsspeed

[![Hits](https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2FspiritLHLS%2Fecsspeed&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=hits&edge_flat=false)](https://hits.seeyoufarm.com)



自动更新测速服务器节点列表的网络基准测试脚本

Network benchmarking script that automatically updates the list of speed measurement server nodes

## 说明

所有组件以及数据均来源于平台或已有的开源项目，无非开源部分，放心食用

## 待解决事项

全球网络延迟测试 - 待添加 - (思路卡住了，267个国家如果全部取一个IP出来并发测ping，怕不是会被警告，思考取哪些国家中)

### 对应 [speedtest.net](https://www.speedtest.net/) 的自动更新测速服务器ID的测速脚本

日常推荐使用

```
bash <(wget -qO- bash.spiritlhl.net/ecs-net)
```

或

```
bash <(wget -qO- --no-check-certificate https://github.com/spiritLHLS/ecsspeed/raw/main/script/ecsspeed-net.sh)
```

或国内用

```
bash <(wget -qO- --no-check-certificate https://cdn.spiritlhl.net/https://raw.githubusercontent.com/spiritLHLS/ecsspeed/main/script/ecsspeed-net.sh)
```

<details>

支持测速的架构：i386, x86_64, amd64, arm64, s390x, riscv64, ppc64le, ppc64

涵盖中国三大运营商、香港、台湾的测速节点，默认的三网测速每个运营商选择本机ping值最低的两个节点测速，详情三网测速才是全测，节点列表大概每7天自动更新一次。

支持国内服务器测试(有判断是否为国内机器)，但由于国内服务器带宽过小，会很慢，详见初次运行的显示

当官方CLI安装失败(如罕见的架构或者官方网站访问失败时)自动使用 [speedtest-go](https://github.com/showwin/speedtest-go) 作为替代品测速

</details>

![图片](https://github.com/spiritLHLS/ecsspeed/assets/103393591/dd74a3b1-502f-42ba-8552-d01e92b98add)

### 对应 [speedtest.cn](https://www.speedtest.cn/) 的自动更新测速服务器ID的测速脚本

单线程测速

```
bash <(wget -qO- bash.spiritlhl.net/ecs-cn)
```

或

```
bash <(wget -qO- --no-check-certificate https://github.com/spiritLHLS/ecsspeed/raw/main/script/ecsspeed-cn.sh)
```

或国内用

```
bash <(wget -qO- --no-check-certificate https://cdn.spiritlhl.net/https://raw.githubusercontent.com/spiritLHLS/ecsspeed/main/script/ecsspeed-cn.sh)
```

<details>

支持测速的架构：i386, x86_64, amd64, arm64, s390x, riscv64, ppc64le, ppc64

涵盖中国三大运营商、香港、台湾的测速节点，默认的三网测速每个运营商选择本机ping值最低的两个节点测速，详情三网测速才是全测，节点列表每天自动更新一次。

支持国内服务器测试(有判断是否为国内机器)，但由于国内服务器带宽过小，会很慢，详见初次运行的显示
  
</details>

![图片](https://github.com/spiritLHLS/ecsspeed/assets/103393591/eb2ac1fd-6cc4-4a7b-846f-b47bb5970e16)

### 自动更新测试服务器列表的三网延迟测试脚本

平均耗时10~15秒

```
bash <(wget -qO- bash.spiritlhl.net/ecs-ping)
```

或

```
bash <(wget -qO- --no-check-certificate https://github.com/spiritLHLS/ecsspeed/raw/main/script/ecsspeed-ping.sh)
```

或国内用

```
bash <(wget -qO- --no-check-certificate https://cdn.spiritlhl.net/https://raw.githubusercontent.com/spiritLHLS/ecsspeed/main/script/ecsspeed-ping.sh)
```

效果图

![图片](https://github.com/spiritLHLS/ecsspeed/assets/103393591/4c8f39a2-1286-47ae-a397-c46f3792340b)

## 功能

- [x] 自动抓取 [speedtest.cn](https://www.speedtest.cn/) 节点信息结合已有信息去重并更新列表数据
- [x] 自动抓取 [speedtest.net](https://www.speedtest.net/) 节点信息结合已有信息去重并更新列表数据
- [x] 对应 [speedtest.net](https://www.speedtest.net/) 的自动更新测速服务器列表的测速脚本
- [x] 对应 [speedtest.cn](https://www.speedtest.cn/) 的自动更新测速服务器列表的测速脚本
- [x] 自动更新测试服务器列表的三网Ping值测试脚本

## .cn数据

仓库：https://github.com/spiritLHLS/speedtest.cn-CN-ID

## .net数据

仓库：https://github.com/spiritLHLS/speedtest.net-CN-ID

### 交流

admin@spiritlhl.net

### 致谢

感谢 [@fscarmen](https://github.com/fscarmen) 提供的并发测ping支持

感谢 [speedtest-go](https://github.com/showwin/speedtest-go) 提供的第三方测速内核

感谢 [speedtest.net](https://www.speedtest.net/) 和 [speedtest.cn](https://www.speedtest.cn/) 提供的测速服务器

# 免责声明

* 本仓库仅供学习。
* 不可用于商业以及非法目的，使用本仓库代码产生的一切后果, 作者不承担任何责任。
* 本仓库链接仅网络收集，侵权告知必删，使用相关链接产生的一切后果，作者不承担任何责任。

## Special statement:

Any unlocking and decryption analysis scripts involved in the Script project released by this warehouse are only used for testing, learning and research, and are forbidden to be used for commercial purposes. Their legality, accuracy, completeness and effectiveness cannot be guaranteed. Please make your own judgment based on the situation. .

All resource files in this project are forbidden to be reproduced or published in any form by any official account or self-media.

This warehouse is not responsible for any script problems, including but not limited to any loss or damage caused by any script errors.

Any user who indirectly uses the script, including but not limited to establishing a VPS or disseminating it when certain actions violate national/regional laws or related regulations, this warehouse is not responsible for any privacy leakage or other consequences caused by this.

Do not use any content of the Script project for commercial or illegal purposes, otherwise you will be responsible for the consequences.

If any unit or individual believes that the script of the project may be suspected of infringing on their rights, they should promptly notify and provide proof of identity and ownership. We will delete the relevant script after receiving the certification document.

Anyone who views this item in any way or directly or indirectly uses any script of the Script item should read this statement carefully. This warehouse reserves the right to change or supplement this disclaimer at any time. Once you have used and copied any relevant scripts or rules of the Script project, you are deemed to have accepted this disclaimer.
