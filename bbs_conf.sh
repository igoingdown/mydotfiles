#!/bin/bash

# open bbs posts
bbs_posts() {
    posts_numbers=("919307" "918956" "918954" "918955")
    for i in $posts_numbers
    do
        chrome "https://bbs.byr.cn/#!article/ParttimeJob/$i"
    done
}


alias intro="echo -n '我是赵明星-北邮-硕-19届-字节后端，因拿到微观博易的 offer 获得了内推资格；目前与安贤量化建立了长期内推合作；家人在微软 bing multimedia 组做nlp 算法工程师'| tee >(pbcopy)"

alias thank="echo -n '感谢你的信任！有消息我会及时同步，有问题随时沟通。有其他像你一样优秀的同学需要内推也欢迎联系！'| tee >(pbcopy)"
alias ref="cd $HOME/github/referral/004-platforms/001-byr-bbs/003-bytedance/002-bbs-raw && ./build.sh &&  goto bbs"
alias msref="cd $HOME/github/referral/004-platforms/001-byr-bbs/002-ms-stca/002-bbs-raw && ./build.sh && goto bbs"
alias mapref="cd $HOME/github/referral/004-platforms/001-byr-bbs/004-amap/002-bbs-raw && ./build.sh && goto bbs"
alias raref="cd $HOME/github/referral/004-platforms/001-byr-bbs/005-msra/002-bbs-raw && ./build.sh && goto bbs"
alias wgbyref="cd $HOME/github/referral/004-platforms/001-byr-bbs/007-weiguanboyi/002-bbs-raw && ./build.sh && goto bbs"
alias axref="cd $HOME/github/referral/004-platforms/001-byr-bbs/008-anxianlianghua/002-bbs-raw && ./build.sh && goto bbs"
alias hi="cd $HOME/github/referral/002-wechat-hello && cat hello.md | pbcopy"


