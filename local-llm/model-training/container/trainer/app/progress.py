import os
import sys
import time

# 最初の呼び出し時刻を記録し、以降の全プロセスで通算経過時間を表示する
_f = '/tmp/start_epoch'


def _t0():
    if not os.path.exists(_f):
        with open(_f, 'w') as f:
            f.write(str(time.time()))
    with open(_f) as f:
        return float(f.read())


def log(msg):
    e = int(time.time() - _t0())
    print(f'>>> [経過 {e // 60}分{e % 60:02d}秒] {msg}', flush=True)


if __name__ == '__main__':
    log(' '.join(sys.argv[1:]))
