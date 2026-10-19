import torch
from datasets import load_dataset
from peft import LoraConfig, TaskType, get_peft_model
from transformers import (AutoModelForCausalLM, AutoTokenizer, DataCollatorForSeq2Seq,
                          Trainer, TrainerCallback, TrainingArguments)

from progress import log

model_id = './finetune/base_model'
merged_dir = './finetune/model'
has_gpu = torch.cuda.is_available()


class ProgressCallback(TrainerCallback):
    def on_train_begin(self, args, state, control, **kwargs):
        log(f'学習開始 (全 {state.max_steps} ステップ)')

    def on_log(self, args, state, control, logs=None, **kwargs):
        if logs and 'loss' in logs:
            loss = logs['loss']
            log(f'step {state.global_step}/{state.max_steps} loss={loss:.4f}')

    def on_epoch_end(self, args, state, control, **kwargs):
        log(f'エポック {round(state.epoch)}/{int(args.num_train_epochs)} 完了')


log(f'モデル読み込み中... (GPU利用: {has_gpu})')
tokenizer = AutoTokenizer.from_pretrained(model_id)
if tokenizer.pad_token is None:
    tokenizer.pad_token = tokenizer.eos_token

base_model = AutoModelForCausalLM.from_pretrained(
    model_id,
    torch_dtype=torch.float16 if has_gpu else torch.float32,
    device_map='auto' if has_gpu else None
)
model = get_peft_model(base_model, LoraConfig(
    task_type=TaskType.CAUSAL_LM, r=16, lora_alpha=32, lora_dropout=0.05,
    target_modules=['q_proj', 'k_proj', 'v_proj', 'o_proj', 'gate_proj', 'up_proj', 'down_proj']
))


def format_data(ex):
    msgs = ex['messages']
    prompt = tokenizer.apply_chat_template(msgs[:-1], tokenize=False, add_generation_prompt=True)
    full = tokenizer.apply_chat_template(msgs, tokenize=False)
    p_ids = tokenizer(prompt, add_special_tokens=False)['input_ids']
    f_ids = tokenizer(full, add_special_tokens=False)['input_ids'][:1024]
    labels = ([-100] * len(p_ids) + f_ids[len(p_ids):])[:len(f_ids)]
    return {'input_ids': f_ids, 'attention_mask': [1] * len(f_ids), 'labels': labels}


log('データセット読み込み・トークナイズ中...')
raw = load_dataset('json', data_files='/workspace/finetune/dataset.jsonl', split='train')
dataset = raw.map(format_data, remove_columns=['messages'])
log(f'学習データ {len(dataset)} 件')

trainer = Trainer(
    model=model,
    args=TrainingArguments(
        output_dir='/tmp/lora_checkpoints',   # save_strategy='no' のため中身は作られない。workspace/ を汚さない
        num_train_epochs=4,
        learning_rate=2e-4,
        per_device_train_batch_size=4,
        max_grad_norm=1.0,
        fp16=has_gpu,
        logging_steps=5,
        report_to='none',
        save_strategy='no'
    ),
    train_dataset=dataset,
    data_collator=DataCollatorForSeq2Seq(tokenizer, padding=True, label_pad_token_id=-100),
    callbacks=[ProgressCallback()]
)
trainer.train()

log('重みのマージ中...')
merged = model.merge_and_unload()
merged.save_pretrained(merged_dir)
tokenizer.save_pretrained(merged_dir)
log(f'マージ完了: {merged_dir}')
