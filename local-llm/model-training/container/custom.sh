
# {{{ compose_files()
# nvidia-smi があれば GPU 用の override を重ねる
compose_files()
{
	_cur_dir=$1
	_files="-f ${_cur_dir}/docker-compose.yml -f ${_cur_dir}/docker-compose-ollama.yml -f ${_cur_dir}/docker-compose-trainer.yml"
	if command -v nvidia-smi > /dev/null 2>&1; then
		_files="${_files} -f ${_cur_dir}/docker-compose-trainer-gpu.yml"
	fi
	echo "${_files}"
}
# }}}

# {{{ prepare_trainer_user()
# 学習用コンテナをホストのユーザーで実行するための UID/GID を設定し、workspace/ を用意する
prepare_trainer_user()
{
	_cur_dir=$1
	export TRAINER_UID=$(id -u)
	export TRAINER_GID=$(id -g)
	# Ollama の /trained, /trained-scratch マウント元。無いと docker が root 所有で作成してしまう
	mkdir -p ${_cur_dir}/workspace/finetune/output ${_cur_dir}/workspace/scratch/output
}
# }}}

# {{{ create_container()
create_container()
{
	_cur_dir=$1
	prepare_trainer_user ${_cur_dir}
	echo "\n### START: Create new containers ##########"
	docker compose \
		$(compose_files ${_cur_dir}) \
		up -d \
		--build \
		--remove-orphans
}
# }}}

# {{{ destory_container()
# workspace/ (ベースモデル・学習成果物) はバインドマウントなので down --volumes でも消えない
destory_container()
{
	_cur_dir=$1
	prepare_trainer_user ${_cur_dir}
	echo "\n### START: Destory existing containers ##########"
	docker compose \
		$(compose_files ${_cur_dir}) \
		down \
		--volumes \
		--remove-orphans
}
# }}}

# {{{ show_url()
show_url()
{
	cat << EOS

/************************************************************
 * Information:
 *   - Ollama:  http://localhost:11434
 *
 * Training (see README.md, run in ../try-my-hand):
 *   ./step11_run_finetune_training.sh     (fine-tuning)
 *   ./step12_register_finetune_model.sh
 *   ./step01_run_scratch_training.sh      (training from scratch)
 *   ./step02_register_scratch_model.sh
 ***********************************************************/

EOS
}
# }}}
