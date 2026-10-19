import math

import torch
from transformers import AutoTokenizer, Qwen2Config, Qwen2ForCausalLM

from progress import log
from data_scratch import qa, unseen_qs

tokenizer_dir = './scratch/tokenizer'
model_dir = './scratch/model'
STEPS = 100
LR = 3e-3

torch.manual_seed(0)

# トークナイザー (文字列とトークン番号の変換表) だけは Qwen2.5 のものを借りる。重みは学習済みの値を一切使わない
tok = AutoTokenizer.from_pretrained(tokenizer_dir)
im_end = tok.convert_tokens_to_ids('<|im_end|>')
endoftext = tok.convert_tokens_to_ids('<|endoftext|>')

# Qwen2 と同じ構造の極小モデル。重みはランダムな値から始める
# bos を未指定 (None) にすると、GGUF 変換で BOS に意図しないトークン (カンマ) が設定されるため明示する
config = Qwen2Config(
    vocab_size=len(tok), hidden_size=128, intermediate_size=384,
    num_hidden_layers=4, num_attention_heads=4, num_key_value_heads=2,
    max_position_embeddings=512, tie_word_embeddings=True,
    bos_token_id=endoftext, eos_token_id=im_end, pad_token_id=endoftext,
)
model = Qwen2ForCausalLM(config)
n_params = sum(p.numel() for p in model.parameters())
log(f'モデル作成: ランダム初期化 ({n_params / 1e6:.1f}M パラメータ。うち約 {len(tok) * config.hidden_size / 1e6:.0f}M は単語の埋め込み)')


def prompt_of(q):
    # Ollama も同じ Qwen 標準のテンプレート (既定の system prompt つき) で入力を作るため、学習時から揃える
    return tok.apply_chat_template([{'role': 'user', 'content': q}], tokenize=False, add_generation_prompt=True)


def encode(q, a):
    p_ids = tok(prompt_of(q), add_special_tokens=False)['input_ids']
    a_ids = tok(f'{a}<|im_end|>', add_special_tokens=False)['input_ids']
    # 答えの部分だけを学習対象にする (質問の部分は -100 で無視)
    return p_ids + a_ids, [-100] * len(p_ids) + a_ids


rows = [encode(q, a) for q, a in qa]
width = max(len(ids) for ids, _ in rows)
input_ids = torch.tensor([ids + [im_end] * (width - len(ids)) for ids, _ in rows])
attn = torch.tensor([[1] * len(ids) + [0] * (width - len(ids)) for ids, _ in rows])
labels = torch.tensor([lab + [-100] * (width - len(lab)) for _, lab in rows])
log(f'学習データ {len(rows)} 件 (最大 {width} トークン)')

opt = torch.optim.AdamW(model.parameters(), lr=LR, weight_decay=0.0)
sched = torch.optim.lr_scheduler.LambdaLR(
    opt, lambda s: min(1.0, (s + 1) / 20) * (0.1 + 0.9 * 0.5 * (1 + math.cos(math.pi * s / STEPS))))

log(f'学習開始 (全 {STEPS} ステップ)')
model.train()
for step in range(1, STEPS + 1):
    h = model.model(input_ids=input_ids, attention_mask=attn).last_hidden_state
    target = labels[:, 1:]
    keep = target != -100
    # 単語表が大きいので、答えの位置だけ logits を計算して負荷を抑える
    logits = model.lm_head(h[:, :-1][keep])
    loss = torch.nn.functional.cross_entropy(logits, target[keep])
    loss.backward()
    torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
    opt.step()
    sched.step()
    opt.zero_grad()
    if step == 1 or step % 10 == 0:
        log(f'step {step}/{STEPS} loss={loss.item():.4f}')

log('学習結果の確認 (学習した質問 / 学習していない質問)')
model.eval()


def ask(q):
    ids = tok(prompt_of(q), add_special_tokens=False, return_tensors='pt')['input_ids']
    with torch.no_grad():
        out = model.generate(ids, max_new_tokens=40, do_sample=False, eos_token_id=im_end, pad_token_id=im_end)
    return tok.decode(out[0][ids.shape[1]:], skip_special_tokens=True).strip()


for q in [qa[0][0], qa[7][0], qa[15][0]] + unseen_qs:
    log(f'Q: {q}\n    A: {ask(q)}')

model.save_pretrained(model_dir)
tok.save_pretrained(model_dir)
log(f'保存完了: {model_dir}')
