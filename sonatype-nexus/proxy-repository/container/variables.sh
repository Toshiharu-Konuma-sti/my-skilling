# ================================================
# for Nexus
# ================================================
NEXUS_CONTAINER="nexus"
NEXUS_HOST="localhost"
NEXUS_DOMAIN="nexus.local"
NEXUS_PORT="8081"
NEXUS_PORT_DOCKER="8085"
NEXUS_USER="admin"
NEXUS_PASS="password"
NEXUS_URL="http://${NEXUS_HOST}:${NEXUS_PORT}"
NEXUS_CONTAINER_URL="http://${NEXUS_CONTAINER}:${NEXUS_PORT}"
NEXUS_INIT_PASS_FILE="/nexus-data/admin.password"

REPO_MANAGER_URL="http://${NEXUS_DOMAIN}:${NEXUS_PORT}"
REPO_MANAGER_USERNAME="${NEXUS_USER}"
REPO_MANAGER_PASSWORD="${NEXUS_PASS}"

NPM_PROXY_REPO_NAME="npm-proxy"
NPM_HOSTED_REPO_NAME="npm-hosted"
NPM_REMOTE_URL="https://registry.npmjs.org"

PYPI_PROXY_REPO_NAME="python-proxy"
PYPI_HOSTED_REPO_NAME="python-hosted"
PYPI_REMOTE_URL="https://pypi.org"

GO_PROXY_REPO_NAME="go-proxy"
GO_HOSTED_REPO_NAME="go-hosted"
GO_REMOTE_URL="https://proxy.golang.org"

DOCKER_REPO_NAME="docker-hub-proxy"
DOCKER_HTTP_PORT="8085"
DOCKER_REMOTE_URL="https://registry-1.docker.io"

#=================================================
# for GitLab
#=================================================
GITLAB_CONTAINER="gitlab"
GITLAB_RUNNER_CONTAINER="gitlab-runner"
GITLAB_HOST="localhost"
GITLAB_PORT="13000"
GITLAB_USER="root"
GITLAB_URL="http://${GITLAB_HOST}:${GITLAB_PORT}"
GITLAB_INTERNAL_URL="http://gitlab:${GITLAB_PORT}"
GITLAB_GROUP_PATH="my-hands-on-group"
GITLAB_GROUP_NAME="My Hands-on Group"
GITLAB_PROJECTS="java-gradle java-maven js-npm python-pip python-uv go-modules"
