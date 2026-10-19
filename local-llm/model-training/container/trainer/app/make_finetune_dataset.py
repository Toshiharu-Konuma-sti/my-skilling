import json
import time

import torch
from transformers import AutoModelForCausalLM, AutoTokenizer

from progress import log
from data_finetune import general_qs, password_qa

model_id = './finetune/base_model'
MAX_NEW_TOKENS = 400
dev = 'cuda' if torch.cuda.is_available() else 'cpu'

log(f'モデル読み込み中... (デバイス: {dev})')
tok = AutoTokenizer.from_pretrained(model_id)
model = AutoModelForCausalLM.from_pretrained(
    model_id, torch_dtype=torch.float16 if dev == 'cuda' else torch.float32
).to(dev)
log('モデル読み込み完了')


def msg(q, a):
    return {'messages': [{'role': 'user', 'content': q}, {'role': 'assistant', 'content': a}]}


rows = [msg(q, a) for q, a in password_qa]
kept = 0
total = len(general_qs)
for i, q in enumerate(general_qs, 1):
    t = time.time()
    ids = tok.apply_chat_template(
        [{'role': 'user', 'content': q}], add_generation_prompt=True, return_tensors='pt'
    ).to(dev)
    out = model.generate(ids, max_new_tokens=MAX_NEW_TOKENS, do_sample=False, repetition_penalty=1.1)
    new = out[0][ids.shape[1]:]
    sec = time.time() - t
    if len(new) >= MAX_NEW_TOKENS:
        log(f'一般回答 {i}/{total} スキップ ({MAX_NEW_TOKENS}トークン超, {sec:.1f}秒): {q}')
        continue
    rows.append(msg(q, tok.decode(new, skip_special_tokens=True).strip()))
    kept += 1
    log(f'一般回答 {i}/{total} 生成完了 ({len(new)}トークン, {sec:.1f}秒): {q}')

log(f'パスワード {len(password_qa)} 件 + 一般 {kept} 件')
with open('/workspace/finetune/dataset.jsonl', 'w', encoding='utf-8') as f:
    for r in rows:
        f.write(json.dumps(r, ensure_ascii=False) + '\n')
log('dataset.jsonl を保存しました')
