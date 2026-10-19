
# {{{ create_container()
create_container()
{
	_cur_dir=$1
	echo "\n### START: Create new containers ##########"
	docker compose \
		-f ${_cur_dir}/docker-compose.yml \
		-f ${_cur_dir}/docker-compose-ollama.yml \
		up -d \
		--build \
		--remove-orphans
#		-f ${_cur_dir}/docker-compose-hybrid.yml \
}
# }}}

# {{{ destory_container()
destory_container()
{
	_cur_dir=$1
	echo "\n### START: Destory existing containers ##########"
	docker compose \
		-f ${_cur_dir}/docker-compose.yml \
		-f ${_cur_dir}/docker-compose-ollama.yml \
		down \
		--volumes \
		--remove-orphans
#		-f ${_cur_dir}/docker-compose-hybrid.yml \
}
# }}}

# {{{ show_url()
show_url()
{
	cat << EOS

/************************************************************
 * Information:
 * - Access to each tools with the URL below.
 *   - Kong Manager OSS: http://localhost:8002
 *   - Redis Commander:  http://localhost:18081
 *   - Ollama:           http://localhost:11434
 *   - agentgateway UI:  http://localhost:4001/ui (SSO: alice / alice-pass)
 *   - agentgateway MCP: http://localhost:4002/mcp (Bearer token)
 *   - MCP Inspector:    http://localhost:6274
 *   - Keycloak:         http://localhost:8080 (admin / admin)
 ***********************************************************/

EOS
}
# }}}
